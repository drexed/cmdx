# frozen_string_literal: true

module CMDx
  module Workflow

    module ClassMethods

      def method_added(method_name)
        raise "cannot redefine #{name}##{method_name} method" if method_name == :task

        super
      end

      def execution_groups
        @execution_groups ||= []
      end

      def tasks(*tasks, **options)
        execution_groups << ExecutionGroup.new(
          tasks.flatten.map do |task|
            next task if task.is_a?(Class) && (task <= Task)

            raise TypeError, "must be a Task or Workflow"
          end,
          options
        )
      end

    end

    ExecutionGroup = Struct.new(:tasks, :options)

    def self.included(base)
      base.extend(ClassMethods)
    end

    def task
      self.class.execution_groups.each do |group|
        next unless Utils::Condition.evaluate(self, group.options)

        workflow_breakpoints = Array(
          group.options[:workflow_breakpoints] ||
          self.class.settings[:workflow_breakpoints]
        ).map(&:to_s)

        group.tasks.each do |task|
          task_result = task.execute(context)
          next unless workflow_breakpoints.include?(task_result.status)

          throw!(task_result)
        end
      end
    end

  end
end

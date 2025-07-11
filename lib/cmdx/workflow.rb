# frozen_string_literal: true

module CMDx
  class Workflow < Task

    Group = Struct.new(:tasks, :options)

    class << self

      def workflow_groups
        @workflow_groups ||= []
      end

      def process(*tasks, **options)
        workflow_groups << Group.new(
          tasks.flatten.map do |task|
            next task if task <= Task

            raise TypeError, "must be a Task or Workflow"
          end,
          options
        )
      end

    end

    def call
      self.class.workflow_groups.each do |group|
        next unless cmdx_eval(group.options)

        workflow_halt = group.options[:workflow_halt] || task_setting(:workflow_halt)

        group.tasks.each do |task|
          task_result = task.call(context)
          next unless Array(workflow_halt).include?(task_result.status)

          throw!(task_result)
        end
      end
    end

  end
end

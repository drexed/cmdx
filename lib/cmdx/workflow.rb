# frozen_string_literal: true

module CMDx
  module Workflow

    # Group = Struct.new(:tasks, :options)

    # module ClassMethods

    # def method_added(method_name)
    #   raise "cannot redefine #{name}##{method_name}" if method_name == :command

    #   super
    # end

    #   def task_groups
    #     @task_groups ||= []
    #   end

    #   def process(*tasks, **options)
    #     task_groups << Group.new(
    #       tasks.flatten.map do |task|
    #         next task if task.is_a?(Class) && (task <= Task)

    #         raise TypeError, "must be a Task or Workflow"
    #       end,
    #       options
    #     )
    #   end

    # end

    # def self.included(base)
    #   base.extend(ClassMethods)
    # end

    # def call
    #   self.class.task_groups.each do |group|
    #     next unless cmdx_eval(group.options)

    #     workflow_halt = Array(
    #       group.options[:workflow_halts] ||
    #       cmd_setting(:workflow_halts)
    #     ).map(&:to_s)

    #     group.tasks.each do |task|
    #       task_result = task.call(context)
    #       next unless workflow_halt.include?(task_result.status)

    #       throw!(task_result)
    #     end
    #   end
    # end

  end
end

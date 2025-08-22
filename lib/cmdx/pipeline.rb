# frozen_string_literal: true

module CMDx
  class Pipeline

    attr_reader :workflow

    def initialize(workflow)
      @workflow = workflow
    end

    def self.execute(workflow)
      new(workflow).execute
    end

    def execute
      workflow.class.pipeline.each do |group|
        next unless Utils::Condition.evaluate(workflow, group.options, workflow)

        breakpoints = group.options[:breakpoints] ||
                      workflow.class.settings[:breakpoints] ||
                      workflow.class.settings[:workflow_breakpoints]
        breakpoints = Array(breakpoints).map(&:to_s).uniq

        execute_group_tasks(group, breakpoints)
      end
    end

    private

    def execute_group_tasks(group, breakpoints)
      # NOTE: Override this method to introduce alternative execution strategies
      execute_tasks_sequentially(group, breakpoints)
    end

    def execute_tasks_sequentially(group, breakpoints)
      group.tasks.each do |task|
        task_result = task.execute(workflow.context)
        next unless breakpoints.include?(task_result.status)

        workflow.throw!(task_result)
      end
    end

  end
end

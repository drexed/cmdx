# frozen_string_literal: true

module CMDx
  # Executes workflows by processing task groups with conditional logic and breakpoint handling.
  # The Pipeline class manages the execution flow of workflow tasks, evaluating conditions
  # and handling breakpoints that can interrupt execution at specific task statuses.
  class Pipeline

    # @return [Workflow] The workflow instance being executed
    attr_reader :workflow

    # @param workflow [Workflow] The workflow to execute
    #
    # @return [Pipeline] A new pipeline instance
    #
    # @example
    #   pipeline = Pipeline.new(my_workflow)
    def initialize(workflow)
      @workflow = workflow
    end

    # Executes a workflow using a new pipeline instance.
    #
    # @param workflow [Workflow] The workflow to execute
    #
    # @return [void]
    #
    # @example
    #   Pipeline.execute(my_workflow)
    def self.execute(workflow)
      new(workflow).execute
    end

    # Executes the workflow by processing all task groups in sequence.
    # Each group is evaluated against its conditions, and breakpoints are checked
    # after each task execution to determine if workflow should continue or halt.
    #
    # @return [void]
    #
    # @example
    #   pipeline = Pipeline.new(my_workflow)
    #   pipeline.execute
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

    # Executes tasks within a group using the configured execution strategy.
    # Override this method to implement custom execution strategies like parallel
    # processing or conditional task execution.
    #
    # @param group [ExecutionGroup] The group of tasks to execute
    # @param breakpoints [Array<String>] Breakpoint statuses that trigger workflow interruption
    #
    # @return [void]
    #
    # @example
    #   def execute_group_tasks(group, breakpoints)
    #     # Custom parallel execution strategy
    #     group.tasks.map { |task| Thread.new { task.execute(workflow.context) } }
    #   end
    def execute_group_tasks(group, breakpoints)
      # NOTE: Override this method to introduce alternative execution strategies
      execute_tasks_sequentially(group, breakpoints)
    end

    # Executes tasks sequentially within a group, checking breakpoints after each task.
    # If a task result status matches a breakpoint, the workflow is interrupted.
    #
    # @param group [ExecutionGroup] The group of tasks to execute
    # @param breakpoints [Array<String>] Breakpoint statuses that trigger workflow interruption
    #
    # @return [void]
    #
    # @raise [HaltError] When a task result status matches a breakpoint
    #
    # @example
    #   execute_tasks_sequentially(group, ["failed", "skipped"])
    def execute_tasks_sequentially(group, breakpoints)
      group.tasks.each do |task|
        task_result = task.execute(workflow.context)
        next unless breakpoints.include?(task_result.status)

        workflow.throw!(task_result)
      end
    end

  end
end

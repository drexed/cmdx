# frozen_string_literal: true

module CMDx
  # Executes workflows by processing task groups with conditional logic and breakpoint handling.
  # The Pipeline class manages the execution flow of workflow tasks, evaluating conditions
  # and handling breakpoints that can interrupt execution at specific task statuses.
  class Pipeline

    # @return [Workflow] The workflow instance being executed
    # @rbs @workflow: Workflow
    attr_reader :workflow

    # @param workflow [Workflow] The workflow to execute
    #
    # @return [Pipeline] A new pipeline instance
    #
    # @example
    #   pipeline = Pipeline.new(my_workflow)
    #
    # @rbs (Workflow workflow) -> void
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
    #
    # @rbs (Workflow workflow) -> void
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
    #
    # @rbs () -> void
    def execute
      workflow.class.pipeline.each do |group|
        next unless Utils::Condition.evaluate(workflow, group.options)

        breakpoints = group.options[:breakpoints] ||
                      workflow.class.settings[:breakpoints] ||
                      workflow.class.settings[:workflow_breakpoints]
        breakpoints = Array(breakpoints).map(&:to_s).uniq

        execute_group_tasks(group, breakpoints)
      end
    end

    private

    # Executes a group of tasks using the specified execution strategy.
    #
    # @param group [CMDx::Group] The task group to execute
    # @param breakpoints [Array<Symbol>] Status values that trigger execution breaks
    # @option group.options [Symbol, String] :strategy Execution strategy (:sequential, :parallel, or nil for default)
    #
    # @return [void]
    #
    # @example
    #   execute_group_tasks(group, ["failed", "skipped"])
    #
    # @rbs (untyped group, Array[String] breakpoints) -> void
    def execute_group_tasks(group, breakpoints)
      case strategy = group.options[:strategy]
      when NilClass, /sequential/ then execute_tasks_in_sequence(group, breakpoints)
      when /parallel/ then execute_tasks_in_parallel(group, breakpoints)
      else raise "unknown execution strategy #{strategy.inspect}"
      end
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
    #   execute_tasks_in_sequence(group, ["failed", "skipped"])
    #
    # @rbs (untyped group, Array[String] breakpoints) -> void
    def execute_tasks_in_sequence(group, breakpoints)
      group.tasks.each do |task|
        task_result = task.execute(workflow.context)
        next unless breakpoints.include?(task_result.status)

        workflow.throw!(task_result)
      end
    end

    # Executes tasks in parallel using the parallel gem.
    #
    # @param group [CMDx::Group] The task group to execute in parallel
    # @param breakpoints [Array<Symbol>] Status values that trigger execution breaks
    # @option group.options [Integer] :in_threads Number of threads to use
    # @option group.options [Integer] :in_processes Number of processes to use
    #
    # @return [void]
    #
    # @raise [HaltError] When a task result status matches a breakpoint
    #
    # @example
    #   execute_tasks_in_parallel(group, ["failed"])
    #
    # @rbs (untyped group, Array[String] breakpoints) -> void
    def execute_tasks_in_parallel(group, breakpoints)
      raise "install the `parallel` gem to use this feature" unless defined?(Parallel)

      parallel_options = group.options.slice(:in_threads, :in_processes)
      throwable_result = nil

      Parallel.each(group.tasks, **parallel_options) do |task|
        Chain.current = workflow.chain

        task_result = task.execute(workflow.context)
        next unless breakpoints.include?(task_result.status)

        raise Parallel::Break, throwable_result = task_result
      end

      return if throwable_result.nil?

      workflow.throw!(throwable_result)
    end

  end
end

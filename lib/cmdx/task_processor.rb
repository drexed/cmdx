# frozen_string_literal: true

module CMDx
  # Handles the execution orchestration of Task instances with middleware and callback support.
  #
  # TaskProcessor provides the core execution logic for Task instances, managing
  # the complete lifecycle including parameter validation, callback execution,
  # middleware processing, error handling, and result finalization. It supports
  # both regular and bang execution modes with different error handling behaviors.
  class TaskProcessor

    # @return [CMDx::Task] The task instance being executed
    attr_reader :task

    # Creates a new TaskProcessor instance for the specified task.
    #
    # @param task [CMDx::Task] the task instance to execute
    #
    # @return [TaskProcessor] a new TaskProcessor instance
    #
    # @example Create processor for a task
    #   task = MyTask.new(user_id: 123)
    #   processor = TaskProcessor.new(task)
    #   processor.task # => #<MyTask:...>
    def initialize(task)
      @task = task
    end

    # Executes the task with full error handling and result management.
    #
    # This method provides safe task execution with comprehensive error handling,
    # automatic result state management, and callback execution. Faults are caught
    # and processed according to task halt settings, while StandardErrors are
    # converted to failed results.
    #
    # @return [Result] the task's result object after execution
    #
    # @raise [UndefinedCallError] if the task doesn't implement a call method
    #
    # @example Execute a task safely
    #   task = MyTask.new(name: "test")
    #   processor = TaskProcessor.new(task)
    #   result = processor.call
    #   result.success? # => true or false
    #
    # @example Handle task with validation errors
    #   task = MyTask.new # missing required parameters
    #   processor = TaskProcessor.new(task)
    #   result = processor.call
    #   result.failed? # => true
    def call
      task.result.runtime do
        before_call
        task.call
      rescue UndefinedCallError => e
        raise(e)
      rescue Fault => e
        if Array(task.task_setting(:task_halt)).include?(e.result.status)
          # No need to clear the Chain since exception is not being re-raised
          task.result.throw!(e.result, original_exception: e)
        end
      rescue StandardError => e
        task.result.fail!(reason: "[#{e.class}] #{e.message}", original_exception: e)
      ensure
        task.result.executed!
        after_call
      end

      terminate_call
    end

    # Executes the task with bang semantics, re-raising exceptions.
    #
    # This method provides strict task execution where exceptions are re-raised
    # after proper cleanup. It clears the execution chain on failures and
    # provides different error handling behavior compared to the regular call method.
    #
    # @return [Result] the task's result object after execution
    #
    # @raise [UndefinedCallError] if the task doesn't implement a call method
    # @raise [Fault] if a fault occurs during execution
    #
    # @example Execute task with strict error handling
    #   task = MyTask.new(name: "test")
    #   processor = TaskProcessor.new(task)
    #   result = processor.call! # raises on failure
    #
    # @example Handle exceptions in bang mode
    #   begin
    #     processor.call!
    #   rescue CMDx::Fault => e
    #     puts "Task failed: #{e.result.status}"
    #   end
    def call!
      task.result.runtime do
        before_call
        task.call
      rescue UndefinedCallError => e
        raise!(e)
      rescue Fault => e
        task.result.executed!

        raise!(e) if Array(task.task_setting(:task_halt)).include?(e.result.status)

        after_call # HACK: treat as NO-OP
      else
        task.result.executed!
        after_call # ELSE: treat as success
      end

      terminate_call
    end

    private

    # Executes pre-execution callbacks and parameter validation.
    #
    # @return [void]
    def before_call
      task.cmd_callbacks.call(task, :before_execution)

      task.result.executing!
      task.cmd_callbacks.call(task, :on_executing)

      task.cmd_callbacks.call(task, :before_validation)
      ParameterValidator.call(task)
      task.cmd_callbacks.call(task, :after_validation)
    end

    # Clears the execution chain and re-raises the given exception.
    #
    # @param exception [Exception] the exception to re-raise after chain cleanup
    #
    # @return [void] this method never returns as it always raises
    #
    # @raise [Exception] always re-raises the provided exception
    def raise!(exception)
      Chain.clear
      raise(exception)
    end

    # Executes post-execution callbacks based on result state and status.
    #
    # @return [void]
    def after_call
      task.cmd_callbacks.call(task, :"on_#{task.result.state}")
      task.cmd_callbacks.call(task, :on_executed) if task.result.executed?

      task.cmd_callbacks.call(task, :"on_#{task.result.status}")
      task.cmd_callbacks.call(task, :on_good) if task.result.good?
      task.cmd_callbacks.call(task, :on_bad) if task.result.bad?

      task.cmd_callbacks.call(task, :after_execution)
    end

    # Finalizes task execution with immutability and logging.
    #
    # @return [Result] the task's result object
    def terminate_call
      Immutator.call(task)
      ResultLogger.call(task.result)
    end

  end
end

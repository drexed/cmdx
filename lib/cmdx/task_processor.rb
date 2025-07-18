# frozen_string_literal: true

module CMDx
  # Core task execution processor handling the complete task lifecycle.
  #
  # TaskProcessor manages the execution pipeline for individual tasks, coordinating
  # parameter validation, callback invocation, error handling, and result state
  # management. It provides both safe execution (capturing exceptions) and unsafe
  # execution (re-raising exceptions) modes through call and call! methods respectively.
  # The processor ensures proper state transitions, handles fault propagation, and
  # maintains execution context throughout the task lifecycle.
  class TaskProcessor

    # @return [CMDx::Task] The task instance being executed
    attr_reader :task

    # Creates a new task processor for the specified task instance.
    #
    # @param task [CMDx::Task] the task instance to process
    #
    # @return [TaskProcessor] a new processor instance for the task
    #
    # @example Create a processor for a task
    #   task = MyTask.new(user_id: 123)
    #   processor = TaskProcessor.new(task)
    def initialize(task)
      @task = task
    end

    class << self

      # Executes the specified task and returns the result without raising exceptions.
      #
      # Creates a new processor instance and executes the task through the complete
      # lifecycle including validation, callbacks, and error handling. Exceptions
      # are captured in the result rather than being raised to the caller.
      #
      # @param task [CMDx::Task] the task instance to execute
      #
      # @return [CMDx::Result] the execution result containing state and status information
      #
      # @example Execute a task safely
      #   task = ProcessDataTask.new(data: raw_data)
      #   result = TaskProcessor.call(task)
      #   puts result.status # => "success", "failed", or "skipped"
      def call(task)
        new(task).call
      end

      # Executes the specified task and raises exceptions on failure.
      #
      # Creates a new processor instance and executes the task through the complete
      # lifecycle. Unlike call, this method will re-raise exceptions including
      # Fault exceptions when their status matches the task's halt configuration.
      #
      # @param task [CMDx::Task] the task instance to execute
      #
      # @return [CMDx::Result] the execution result on success
      #
      # @raise [CMDx::Fault] when a fault occurs with status matching task halt configuration
      # @raise [StandardError] when unexpected errors occur during execution
      #
      # @example Execute a task with exception raising
      #   task = CriticalTask.new(operation: "delete")
      #   begin
      #     result = TaskProcessor.call!(task)
      #     puts "Success: #{result.status}"
      #   rescue CMDx::Fault => e
      #     puts "Task failed: #{e.message}"
      #   end
      def call!(task)
        new(task).call!
      end

    end

    # Executes the task with safe error handling and returns the result.
    #
    # Runs the complete task execution pipeline including parameter validation,
    # callback invocation, and the task's call method. Captures all exceptions
    # as result status rather than raising them, ensuring the chain continues
    # execution. Handles both standard errors and Fault exceptions according
    # to the task's halt configuration.
    #
    # @return [CMDx::Result] the execution result with captured state and status
    #
    # @example Safe task execution
    #   processor = TaskProcessor.new(task)
    #   result = processor.call
    #   if result.success?
    #     puts "Task completed successfully"
    #   else
    #     puts "Task failed: #{result.metadata[:reason]}"
    #   end
    def call
      task.result.runtime do
        before_call
        validate_parameters
        task.call
      rescue UndefinedCallError => e
        raise(e)
      rescue Fault => e
        if Array(task.cmd_setting(:task_halt)).include?(e.result.status)
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

    # Executes the task with exception raising on halt conditions.
    #
    # Runs the complete task execution pipeline including parameter validation,
    # callback invocation, and the task's call method. Unlike call, this method
    # will re-raise Fault exceptions when their status matches the task's halt
    # configuration, and clears the execution chain before raising.
    #
    # @return [CMDx::Result] the execution result on successful completion
    #
    # @raise [CMDx::Fault] when a fault occurs with status matching task halt configuration
    # @raise [CMDx::UndefinedCallError] when the task's call method is not implemented
    # @raise [StandardError] when unexpected errors occur during execution
    #
    # @example Task execution with exception raising
    #   processor = TaskProcessor.new(critical_task)
    #   begin
    #     result = processor.call!
    #     puts "Task succeeded"
    #   rescue CMDx::Fault => e
    #     puts "Critical failure: #{e.message}"
    #     # Chain is cleared, execution stops
    #   end
    def call!
      task.result.runtime do
        before_call
        validate_parameters
        task.call
      rescue UndefinedCallError => e
        raise!(e)
      rescue Fault => e
        task.result.executed!

        raise!(e) if Array(task.cmd_setting(:task_halt)).include?(e.result.status)

        after_call # HACK: treat as NO-OP
      else
        task.result.executed!
        after_call # ELSE: treat as success
      end

      terminate_call
    end

    private

    # Executes pre-execution callbacks and sets the task to executing state.
    #
    # Invokes before_execution callbacks, transitions the result to executing
    # state, and triggers on_executing callbacks. This method prepares the
    # task for execution and notifies registered callbacks about the state change.
    #
    # @return [void]
    def before_call
      task.cmd_callbacks.call(task, :before_execution)

      task.result.executing!
      task.cmd_callbacks.call(task, :on_executing)
    end

    # Validates task parameters and handles validation failures.
    #
    # Executes parameter validation callbacks, validates all task parameters
    # against their defined rules, and sets the task result to failed if
    # validation errors are found. Collects all validation messages into
    # the result metadata.
    #
    # @return [void]
    def validate_parameters
      task.cmd_callbacks.call(task, :before_validation)

      task.cmd_parameters.validate!(task)
      unless task.errors.empty?
        task.result.fail!(
          reason: task.errors.full_messages.join(". "),
          messages: task.errors.messages
        )
      end

      task.cmd_callbacks.call(task, :after_validation)
    end

    # Clears the execution chain and raises the specified exception.
    #
    # This method is used to clean up the execution context before
    # re-raising exceptions, ensuring that the chain state is properly
    # reset when execution cannot continue.
    #
    # @param exception [Exception] the exception to raise after clearing the chain
    #
    # @return [void]
    #
    # @raise [Exception] the provided exception after chain cleanup
    def raise!(exception)
      Chain.clear
      raise(exception)
    end

    # Executes post-execution callbacks based on task result state and status.
    #
    # Invokes appropriate callbacks based on the task's final execution state
    # (success, failure, etc.) and status. Handles both state-specific and
    # status-specific callback invocation, as well as general execution
    # completion callbacks.
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

    # Finalizes task execution by freezing state and logging results.
    #
    # Applies immutability to the task instance and logs the execution
    # result. This method ensures that the task state cannot be modified
    # after execution and provides visibility into the execution outcome.
    #
    # @return [void]
    def terminate_call
      Immutator.call(task)
      ResultLogger.call(task.result)
    end

  end
end

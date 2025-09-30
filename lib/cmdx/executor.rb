# frozen_string_literal: true

module CMDx
  # Executes CMDx tasks with middleware support, error handling, and lifecycle management.
  #
  # The Executor class is responsible for orchestrating task execution, including
  # pre-execution validation, execution with middleware, post-execution callbacks,
  # and proper error handling for different types of failures.
  class Executor

    attr_reader :task

    # @param task [CMDx::Task] The task to execute
    #
    # @return [CMDx::Executor] A new executor instance
    #
    # @example
    #   executor = CMDx::Executor.new(my_task)
    def initialize(task)
      @task = task
    end

    # Executes a task with optional exception raising.
    #
    # @param task [CMDx::Task] The task to execute
    # @param raise [Boolean] Whether to raise exceptions (default: false)
    #
    # @return [CMDx::Result] The execution result
    #
    # @raise [StandardError] When raise is true and execution fails
    #
    # @example
    #   CMDx::Executor.execute(my_task)
    #   CMDx::Executor.execute(my_task, raise: true)
    def self.execute(task, raise: false)
      instance = new(task)
      raise ? instance.execute! : instance.execute
    end

    # Executes the task with graceful error handling.
    #
    # @return [CMDx::Result] The execution result
    #
    # @example
    #   executor = CMDx::Executor.new(my_task)
    #   result = executor.execute
    def execute
      task.class.settings[:middlewares].call!(task) do
        pre_execution! unless @pre_execution
        execution!
      rescue UndefinedMethodError => e
        raise(e) # No need to clear the Chain since exception is not being re-raised
      rescue Fault => e
        task.result.throw!(e.result, halt: false, cause: e)
      rescue StandardError => e
        retry if retry_execution?(e)
        task.result.fail!("[#{e.class}] #{e.message}", halt: false, cause: e)
        task.class.settings[:exception_handler]&.call(task, e)
      ensure
        task.result.executed!
        post_execution!
      end

      finalize_execution!
    end

    # Executes the task with exception raising on failure.
    #
    # @return [CMDx::Result] The execution result
    #
    # @raise [StandardError] When execution fails
    #
    # @example
    #   executor = CMDx::Executor.new(my_task)
    #   result = executor.execute!
    def execute!
      task.class.settings[:middlewares].call!(task) do
        pre_execution! unless @pre_execution
        execution!
      rescue UndefinedMethodError => e
        raise_exception(e)
      rescue Fault => e
        task.result.throw!(e.result, halt: false, cause: e)
        halt_execution?(e) ? raise_exception(e) : post_execution!
      rescue StandardError => e
        retry if retry_execution?(e)
        task.result.fail!("[#{e.class}] #{e.message}", halt: false, cause: e)
        raise_exception(e)
      else
        task.result.executed!
        post_execution!
      end

      finalize_execution!
    end

    protected

    # Determines if execution should halt based on breakpoint configuration.
    #
    # @param exception [Exception] The exception that occurred
    #
    # @return [Boolean] Whether execution should halt
    #
    # @example
    #   halt_execution?(fault_exception)
    def halt_execution?(exception)
      breakpoints = task.class.settings[:breakpoints] || task.class.settings[:task_breakpoints]
      breakpoints = Array(breakpoints).map(&:to_s).uniq

      breakpoints.include?(exception.result.status)
    end

    # Determines if execution should be retried based on retry configuration.
    #
    # @param exception [Exception] The exception that occurred
    #
    # @return [Boolean] Whether execution should be retried
    #
    # @example
    #   retry_execution?(standard_error)
    def retry_execution?(exception)
      available_retries = (task.class.settings[:retries] || 0).to_i
      return false unless available_retries.positive?

      current_retries = (task.result.metadata[:retries] ||= 0).to_i
      remaining_retries = available_retries - current_retries
      return false unless remaining_retries.positive?

      exceptions = Array(task.class.settings[:retry_on] || StandardError)
      return false unless exceptions.any? { |e| exception.class <= e }

      task.result.metadata[:retries] += 1

      task.logger.warn do
        reason = "[#{exception.class}] #{exception.message}"
        task.to_h.merge!(reason:, remaining_retries:)
      end

      jitter = task.class.settings[:retry_jitter].to_f * current_retries
      sleep(jitter) if jitter.positive?

      true
    end

    # Raises an exception and clears the chain.
    #
    # @param exception [Exception] The exception to raise
    #
    # @raise [Exception] The provided exception
    #
    # @example
    #   raise_exception(standard_error)
    def raise_exception(exception)
      Chain.clear

      raise(exception)
    end

    # Invokes callbacks of a specific type for the task.
    #
    # @param type [Symbol] The type of callback to invoke
    #
    # @return [void]
    #
    # @example
    #   invoke_callbacks(:before_execution)
    def invoke_callbacks(type)
      task.class.settings[:callbacks].invoke(type, task)
    end

    private

    # Lazy loaded repeator instance to handle retries.
    def repeator
      @repeator ||= Repeator.new(task)
    end

    # Performs pre-execution tasks including validation and attribute verification.
    def pre_execution!
      @pre_execution = true

      invoke_callbacks(:before_validation)

      task.class.settings[:attributes].define_and_verify(task)
      return if task.errors.empty?

      task.result.fail!(
        Locale.t("cmdx.faults.invalid"),
        errors: {
          full_message: task.errors.to_s,
          messages: task.errors.to_h
        }
      )
    end

    # Executes the main task logic.
    def execution!
      invoke_callbacks(:before_execution)

      task.result.executing!
      task.work
    end

    # Performs post-execution tasks including callback invocation.
    def post_execution!
      invoke_callbacks(:"on_#{task.result.state}")
      invoke_callbacks(:on_executed) if task.result.executed?

      invoke_callbacks(:"on_#{task.result.status}")
      invoke_callbacks(:on_good) if task.result.good?
      invoke_callbacks(:on_bad) if task.result.bad?
    end

    # Finalizes execution by freezing the task and logging results.
    def finalize_execution!
      log_execution!
      log_backtrace! if task.class.settings[:backtrace]

      freeze_execution!
      clear_chain!
    end

    # Logs the execution result at the configured log level.
    def log_execution!
      task.logger.info { task.result.to_h }
    end

    # Logs the backtrace of the exception if the task failed.
    def log_backtrace!
      return unless task.result.failed?

      exception = task.result.caused_failure.cause
      return if exception.is_a?(Fault)

      task.logger.error do
        "[#{exception.class}] #{exception.message}\n" <<
          if (cleaner = task.class.settings[:backtrace_cleaner])
            cleaner.call(exception.backtrace).join("\n\t")
          else
            exception.full_message(highlight: false)
          end
      end
    end

    # Freezes the task and its associated objects to prevent modifications.
    def freeze_execution!
      # Stubbing on frozen objects is not allowed in most test environments.
      skip_freezing = ENV.fetch("SKIP_CMDX_FREEZING", false)
      return if Coercions::Boolean.call(skip_freezing)

      task.freeze
      task.result.freeze

      # Freezing the context and chain can only be done
      # once the outer-most task has completed.
      return unless task.result.index.zero?

      task.context.freeze
      task.chain.freeze
    end

    def clear_chain!
      return unless task.result.index.zero?

      Chain.clear
    end

  end
end

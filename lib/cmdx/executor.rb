# frozen_string_literal: true

module CMDx
  # Executes CMDx tasks with middleware support, error handling, and lifecycle management.
  #
  # The Executor class is responsible for orchestrating task execution, including
  # pre-execution validation, execution with middleware, post-execution callbacks,
  # and proper error handling for different types of failures.
  class Executor

    extend Forwardable

    # Returns the task being executed.
    #
    # @return [Task] The task instance
    #
    # @example
    #   executor.task.id # => "abc123"
    #
    # @rbs @task: Task
    attr_reader :task

    def_delegators :task, :result

    # @param task [CMDx::Task] The task to execute
    #
    # @return [CMDx::Executor] A new executor instance
    #
    # @example
    #   executor = CMDx::Executor.new(my_task)
    #
    # @rbs (Task task) -> void
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
    #
    # @rbs (Task task, raise: bool) -> Result
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
    #
    # @rbs () -> Result
    def execute
      task.class.settings.middlewares.call!(task) do
        pre_execution! unless @pre_execution
        execution!
        verify_context_returns!
      rescue UndefinedMethodError => e
        raise_exception(e)
      rescue Fault => e
        result.throw!(e.result, halt: false, cause: e)
      rescue StandardError => e
        retry if retry_execution?(e)
        result.fail!("[#{e.class}] #{e.message}", halt: false, cause: e)
        task.class.settings.exception_handler&.call(task, e)
      ensure
        result.executed!
        post_execution!
      end

      verify_middleware_yield!
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
    #
    # @rbs () -> Result
    def execute!
      task.class.settings.middlewares.call!(task) do
        pre_execution! unless @pre_execution
        execution!
        verify_context_returns!
      rescue UndefinedMethodError => e
        raise_exception(e)
      rescue Fault => e
        result.throw!(e.result, halt: false, cause: e)

        if halt_execution?(e)
          raise_exception(e)
        else
          result.executed!
          post_execution!
        end
      rescue StandardError => e
        retry if retry_execution?(e)
        result.fail!("[#{e.class}] #{e.message}", halt: false, cause: e)
        raise_exception(e)
      else
        result.executed!
        post_execution!
      end

      verify_middleware_yield!
      finalize_execution!
    end

    protected

    # Determines if execution should halt based on breakpoint configuration.
    #
    # @param exception [Exception] The exception that occurred
    #
    # @return [Boolean] Whether execution should halt
    #
    # @rbs (Exception exception) -> bool
    def halt_execution?(exception)
      @halt_statuses ||= begin
        settings = task.class.settings
        statuses = settings.breakpoints || settings.task_breakpoints
        Utils::Wrap.array(statuses).map(&:to_s).uniq
      end

      @halt_statuses.include?(exception.result.status)
    end

    # Determines if execution should be retried based on retry configuration.
    #
    # @param exception [Exception] The exception that occurred
    #
    # @return [Boolean] Whether execution should be retried
    #
    # @rbs (Exception exception) -> bool
    def retry_execution?(exception)
      @retry ||= Retry.new(task)

      return false unless @retry.available? && @retry.remaining?
      return false unless @retry.exception?(exception)

      result.retries += 1

      task.logger.warn do
        reason = "[#{exception.class}] #{exception.message}"
        task.to_h.merge!(reason:, remaining_retries: @retry.remaining)
      end

      task.errors.clear

      wait = @retry.wait
      sleep(wait) if wait.positive?

      true
    end

    # Raises an exception and clears the chain.
    #
    # @param exception [Exception] The exception to raise
    #
    # @raise [Exception] The provided exception
    #
    # @rbs (Exception exception) -> void
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
    #
    # @rbs (Symbol type) -> void
    def invoke_callbacks(type)
      task.class.settings.callbacks.invoke(type, task)
    end

    private

    # Performs pre-execution tasks including validation and attribute verification.
    #
    # @rbs () -> void
    def pre_execution!
      @pre_execution = true

      invoke_callbacks(:before_validation)

      task.class.settings.attributes.define_and_verify(task)
      return if task.errors.empty?

      result.fail!(
        Locale.t("cmdx.faults.invalid"),
        errors: {
          full_message: task.errors.to_s,
          messages: task.errors.to_h
        }
      )
    end

    # Executes the main task logic.
    #
    # @rbs () -> void
    def execution!
      invoke_callbacks(:before_execution)

      result.executing!
      task.work
    end

    # Verifies that all declared returns are present in the context after execution.
    #
    # @rbs () -> void
    def verify_context_returns!
      return unless result.success?

      returns = Utils::Wrap.array(task.class.settings.returns)
      missing = returns.reject { |name| task.context.key?(name) }
      return if missing.empty?

      missing.each { |name| task.errors.add(name, Locale.t("cmdx.returns.missing")) }

      result.fail!(
        Locale.t("cmdx.faults.invalid"),
        errors: {
          full_message: task.errors.to_s,
          messages: task.errors.to_h
        }
      )
    end

    # Performs post-execution tasks including callback invocation.
    #
    # @rbs () -> void
    def post_execution!
      invoke_callbacks(:"on_#{result.state}")
      invoke_callbacks(:on_executed) if result.executed?

      invoke_callbacks(:"on_#{result.status}")
      invoke_callbacks(:on_good) if result.good?
      invoke_callbacks(:on_bad) if result.bad?
    end

    # Detects if middleware swallowed the block without yielding.
    # When this happens the result is still in the initialized state.
    #
    # @rbs () -> void
    def verify_middleware_yield!
      return unless result.initialized?

      result.fail!(
        Locale.t("cmdx.faults.invalid"),
        halt: false,
        source: :swallowed_middleware
      )
      result.executed!
    end

    # Finalizes execution by freezing the task, logging results, and rolling back work.
    #
    # @rbs () -> void
    def finalize_execution!
      log_execution!
      log_backtrace! if task.class.settings.backtrace

      rollback_execution!
      freeze_execution!
      clear_chain!
    end

    # Logs the execution result at the configured log level.
    #
    # @rbs () -> void
    def log_execution!
      task.logger.info { result.to_h }
    end

    # Logs the backtrace of the exception if the task failed.
    #
    # @rbs () -> void
    def log_backtrace!
      return unless result.failed?

      exception = result.caused_failure&.cause
      return if exception.nil? || exception.is_a?(Fault)

      task.logger.error do
        "[#{exception.class}] #{exception.message}\n" <<
          if (cleaner = task.class.settings.backtrace_cleaner)
            cleaner.call(exception.backtrace).join("\n\t")
          else
            exception.full_message(highlight: false)
          end
      end
    end

    # Freezes the task and its associated objects to prevent modifications.
    #
    # @rbs () -> void
    def freeze_execution!
      # Stubbing on frozen objects is not allowed in most test environments.
      return unless CMDx.configuration.freeze_results

      task.freeze
      result.freeze

      # Freezing the context and chain can only be done once the outer-most
      # task has completed.
      return unless result.index.zero?

      task.context.freeze
      task.chain.freeze
    end

    # Clears the chain if the task is the outermost (top-level) task
    # and the current thread's chain is the same instance this task belongs to.
    #
    # @rbs () -> void
    def clear_chain!
      return unless result.index.zero?
      return unless Chain.current.equal?(task.chain)

      Chain.clear
    end

    # Rolls back the work of a task.
    #
    # @rbs () -> void
    def rollback_execution!
      return if result.rolled_back?
      return unless task.respond_to?(:rollback)

      statuses = Utils::Wrap.array(task.class.settings.rollback_on).map(&:to_s).uniq
      return unless statuses.include?(result.status)

      result.rolled_back = true
      task.rollback
    end

  end
end

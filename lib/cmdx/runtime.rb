# frozen_string_literal: true

module CMDx
  # Stateless orchestrator for task execution.
  # Creates a Session, runs the full lifecycle, and produces a frozen Result.
  class Runtime

    # @param task_class [Class<Task>]
    # @param args [Hash]
    # @param raise_on_fault [Boolean]
    # @return [Result]
    #
    # @rbs (Class task_class, Hash[Symbol, untyped] args, ?raise_on_fault: bool) ?{ (Result) -> void } -> Result
    def self.call(task_class, args, raise_on_fault: false, &block)
      new(task_class, args).run(raise_on_fault:, &block)
    end

    # @rbs (Class task_class, Hash[Symbol, untyped] args) -> void
    def initialize(task_class, args)
      @task_class = task_class
      @args = args
    end

    # @rbs (?raise_on_fault: bool) ?{ (Result) -> void } -> Result
    def run(raise_on_fault: false, &block)
      @definition = Definition.fetch(@task_class)
      @session = Session.new(@definition, @args)

      deprecation_check!
      prepare_task!

      begin
        validate_attributes! if @definition.attributes.any?
        execute_with_retries! if @session.outcome.success?
        verify_returns! if @session.outcome.success?
      rescue UndefinedMethodError
        @definition = nil
        @task_class.remove_instance_variable(:@cmdx_definition) if @task_class.instance_variable_defined?(:@cmdx_definition)
        raise
      rescue Fault => e
        apply_fault(e)
      rescue StandardError => e
        handle_exception(e)
      end

      finalize!(raise_on_fault:, &block)
    end

    private

    # @rbs () -> void
    def deprecation_check!
      dep = @definition.deprecate
      return unless dep

      Deprecator.check!(@task_class, dep)
    end

    # @rbs () -> void
    def prepare_task!
      @task = @task_class.allocate
      @task.instance_variable_set(:@context, @session.context)
      @task.instance_variable_set(:@_attributes, {})
      @task.instance_variable_set(:@_signal, nil)
      @task.instance_variable_set(:@_success, nil)

      setup_chain!
      @task.send(:initialize) if @task.class.instance_method(:initialize).owner == @task.class
    end

    # @rbs () -> void
    def setup_chain!
      @owner = Chain.current.nil?
      @chain = Chain.current || Chain.new(dry_run: !!@session.context[:dry_run])
      Chain.current = @chain
    end

    # @rbs () -> void
    def validate_attributes!
      CallbackRunner.run(:before_validation, @definition.callbacks, @task, nil)

      resolved = ValueResolver.resolve_all(
        @definition.attributes,
        @session.context,
        coercions: @definition.coercions,
        validators: @definition.validators,
        errors: @session.errors,
        task: @task
      )

      @task.instance_variable_set(:@_attributes, resolved)
      define_attribute_readers!

      return if @session.errors.empty?

      @session.outcome.fail!(
        Locale.t("cmdx.faults.invalid"),
        source: :validation, errors: @session.errors.to_h
      )
    end

    # @rbs () -> void
    def define_attribute_readers!
      resolved = @task.instance_variable_get(:@_attributes)
      mod = Module.new do
        resolved.each_key do |name|
          define_method(name) { @_attributes[name] } unless method_defined?(name)
        end
      end
      @task.extend(mod)
    end

    # @rbs () -> void
    def execute_with_retries!
      attempts = 0
      max_retries = @definition.retry_policy&.max_retries || 0

      begin
        run_middleware_and_work!
      rescue StandardError => e
        attempts += 1
        if attempts <= max_retries && retry_matches?(e)
          @session.outcome.retries = attempts
          @session.errors.clear
          @task.instance_variable_set(:@_signal, nil)
          @task.instance_variable_set(:@_success, nil)
          sleep_with_jitter(attempts)
          retry
        end

        @session.outcome.fail!(e.message, cause: e)
      end
    end

    # @rbs () -> void
    def run_middleware_and_work!
      CallbackRunner.run(:before_execution, @definition.callbacks, @task, nil)
      @session.outcome.executing!

      MiddlewareStack.call(@definition.middleware, MiddlewareEnv.new(session: @session, task: @task)) do
        execute_work
      end
    end

    # @rbs () -> void
    def execute_work
      signal = catch(Outcome::HALT_TAG) do
        @task.work
        nil
      end

      signal ||= @task.instance_variable_get(:@_signal)

      if signal
        @session.outcome.apply_signal(signal)
      elsif (success_data = @task.instance_variable_get(:@_success))
        @session.outcome.merge_metadata!(success_data[:metadata] || {})
      end
    end

    # @rbs () -> void
    def verify_returns!
      @definition.returns.each do |ret|
        next if ret[:options]&.dig(:if) && !Utils::Condition.evaluate(@task, ret[:options][:if])
        next if ret[:options]&.dig(:unless) && Utils::Condition.evaluate(@task, ret[:options][:unless])
        next if @session.context.key?(ret[:name])

        @session.errors.add(ret[:name], Locale.t("cmdx.returns.missing"), :missing_return)
      end

      return if @session.errors.empty?

      @session.outcome.fail!(
        Locale.t("cmdx.faults.invalid"),
        source: :context, errors: @session.errors.to_h
      )
    end

    # @rbs (Fault e) -> void
    def apply_fault(e)
      @session.outcome.fail!(e.message, cause: e)
    end

    # @rbs (StandardError e) -> void
    def handle_exception(e)
      return if @session.outcome.interrupted?

      @session.outcome.fail!(e.message, cause: e)

      if @definition.backtrace
        bt = e.backtrace || []
        bt = @definition.backtrace_cleaner.call(bt) if @definition.backtrace_cleaner
        @session.outcome.merge_metadata!(backtrace: bt)
      end

      handler = @definition.exception_handler
      Utils::Call.invoke(handler, @task, e) if handler
    end

    # @rbs (?raise_on_fault: bool) ?{ (Result) -> void } -> Result
    def finalize!(raise_on_fault: false, &block)
      @session.outcome.finalize_state! unless @session.outcome.executed?

      result = Result.new(
        task_id: @task.respond_to?(:id) ? @task.id : Identifier.generate,
        task_class: @task_class,
        outcome: @session.outcome,
        context: @session.context,
        errors: @session.errors,
        chain: @chain,
        trace_id: @session.trace.id,
        tags: @definition.tags,
        index: @chain.next_index
      )

      @chain.push(result)

      @task.instance_variable_set(:@_result, result)
      invoke_status_callbacks(result)
      invoke_state_callbacks(result)
      CallbackRunner.run(:on_executed, @definition.callbacks, @task, result)

      log_result(result)
      maybe_rollback!(result)
      @task.remove_instance_variable(:@_result) if @task.instance_variable_defined?(:@_result)

      yield result if block

      if @owner
        Chain.clear
        @session.context.freeze
        @chain.freeze
      end

      raise_fault!(result) if raise_on_fault

      result
    end

    # @rbs (Result result) -> void
    def invoke_status_callbacks(result)
      phase = :"on_#{result.status}"
      CallbackRunner.run(phase, @definition.callbacks, @task, result)
      CallbackRunner.run(result.good? ? :on_good : :on_bad, @definition.callbacks, @task, result)
    end

    # @rbs (Result result) -> void
    def invoke_state_callbacks(result)
      phase = result.complete? ? :on_complete : :on_interrupted
      CallbackRunner.run(phase, @definition.callbacks, @task, result)
    end

    # @rbs (Result result) -> void
    def log_result(result)
      @session.logger.info(result.to_s)
    rescue StandardError
      # Swallow logging errors
    end

    # @rbs (Result result) -> void
    def maybe_rollback!(result)
      return if result.success?
      return unless @definition.rollback_on.include?(result.status)
      return unless @task.respond_to?(:rollback)

      begin
        @task.rollback
        @session.outcome.rolled_back = true
      rescue StandardError
        # Swallow rollback errors
      end
    end

    # @rbs (Result result) -> void
    def raise_fault!(result)
      return if result.success?
      return unless @definition.task_breakpoints.include?(result.status)

      fault_class = result.failed? ? FailFault : SkipFault
      raise fault_class.new(result.reason, result:)
    end

    # @rbs (StandardError e) -> bool
    def retry_matches?(e)
      @definition.retry_policy&.matches?(e) || false
    end

    # @rbs (Integer attempt) -> void
    def sleep_with_jitter(attempt)
      @definition.retry_policy&.wait(attempt)
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Single orchestrator for the full task lifecycle.
  # Replaces the old Executor + Resolver split.
  # Creates the Task, catches signals, builds the frozen Result.
  class Runtime

    # @return [Class] the task class being executed
    # @rbs @task_class: untyped
    attr_reader :task_class

    # Entry point for task execution.
    #
    # @param task_class [Class] the task class
    # @param args [Hash] input arguments
    # @param raise_on_fault [Boolean] whether to raise on non-success
    #
    # @return [Result] the frozen result
    #
    # @rbs (untyped task_class, Hash[Symbol, untyped] args, ?raise_on_fault: bool) ?{ (Result) -> void } -> Result
    def self.call(task_class, args = {}, raise_on_fault: false, &block)
      new(task_class, args).call(raise_on_fault:, &block)
    end

    # @param task_class [Class] the task class
    # @param args [Hash] input arguments
    #
    # @rbs (untyped task_class, Hash[Symbol, untyped] args) -> void
    def initialize(task_class, args)
      @task_class = task_class
      @args = args
      @outcome = Outcome.new
      @errors = Errors.new
      @task = nil
      @context = nil
      @chain = nil
      @owns_chain = false
      @result = nil
      @task_id = Identifier.generate
      @retry_strategy = RetryStrategy.new(task_class.task_settings)
    end

    # Runs the full lifecycle.
    #
    # @param raise_on_fault [Boolean] whether to raise on non-success
    #
    # @return [Result]
    #
    # @rbs (?raise_on_fault: bool) ?{ (Result) -> void } -> Result
    def call(raise_on_fault: false, &block)
      deprecation_check!
      prepare_task!
      validate_attributes!
      execute_with_retries! if @outcome.success?
      verify_returns! if @outcome.success?
    rescue UndefinedMethodError => e
      raise e
    rescue Fault => e
      apply_fault(e)
    rescue StandardError => e
      @outcome.status = "failed"
      @outcome.reason = e.message
      @outcome.cause = e
    ensure
      finalize!(&block)
      raise_fault! if raise_on_fault && !@outcome.success?
      return @result # rubocop:disable Lint/EnsureReturn
    end

    private

    # @rbs () -> void
    def deprecation_check!
      Deprecator.check!(task_class)
    end

    # @rbs () -> void
    def prepare_task!
      @context = Context.build(@args)
      @task = task_class.allocate
      @task.instance_variable_set(:@context, @context)
      @task.instance_variable_set(:@_signal, nil)
      @task.instance_variable_set(:@_success, nil)
      @task.instance_variable_set(:@_attributes, {})
      @task.__send__(:initialize)
      parent_chain = Chain.current
      @owns_chain = parent_chain.nil?
      @chain = parent_chain || Chain.new(dry_run: @context[:dry_run])
      Chain.current = @chain
    end

    # @rbs () -> void
    def validate_attributes!
      registry = task_class.attribute_registry
      return unless registry.any?

      invoke_callbacks(:before_validation)

      resolved = registry.resolve(@task, @context, @errors)
      @task.instance_variable_set(:@_attributes, resolved)

      return unless @errors.any?

      @outcome.status = "failed"
      @outcome.reason = Locale.t("cmdx.faults.invalid")
    end

    # @rbs () -> void
    def run_middleware_and_work!
      invoke_callbacks(:before_execution)
      @outcome.state = "executing"

      task_class.middleware_registry.call(@task) do
        execute_work
      end
    end

    # @rbs () -> void
    def execute_work
      signal = catch(:cmdx_signal) do
        @task.work
        @task.instance_variable_get(:@_signal)
      end

      if signal
        @outcome.apply_signal(signal)
      elsif (success_data = @task.instance_variable_get(:@_success))
        @outcome.metadata = @outcome.metadata.merge(success_data[:metadata] || {})
        @outcome.reason = success_data[:reason] if success_data[:reason]
      end
    end

    # @rbs () -> void
    def verify_returns!
      return unless task_class.respond_to?(:returns_registry) && task_class.returns_registry.any?

      task_class.returns_registry.each do |name, opts|
        next if @context.key?(name)
        next if opts[:if] && !Utils::Condition.truthy?(opts[:if], @task)
        next if opts[:unless] && !Utils::Condition.falsy?(opts[:unless], @task)

        @errors.add(name, Locale.t("cmdx.returns.missing"))
      end

      return unless @errors.any? && @outcome.success?

      @outcome.status = "failed"
      @outcome.reason = Locale.t("cmdx.faults.invalid")
    end

    # @rbs () -> void
    def execute_with_retries!
      run_middleware_and_work!
    rescue StandardError => e
      if @retry_strategy.should_retry?(e, @outcome.retries)
        @outcome.retries += 1
        @retry_strategy.wait
        @task.instance_variable_set(:@_signal, nil)
        @task.instance_variable_set(:@_success, nil)
        retry
      end

      @outcome.status = "failed"
      @outcome.reason = e.message
      @outcome.cause = e
    end

    # @rbs (Fault e) -> void
    def apply_fault(e)
      @outcome.status = "failed"
      @outcome.reason = e.message
      @outcome.cause = e
    end

    # @rbs () ?{ (Result) -> void } -> void
    def finalize!(&block)
      @outcome.state = @outcome.success? ? "complete" : "interrupted"
      build_result
      @chain.push(@result)

      inject_result_for_callbacks!
      invoke_status_callbacks
      invoke_state_callbacks
      log_result!
      rollback! unless @outcome.success?
      remove_result_from_task!

      block&.call(@result)

      return unless @owns_chain

      Chain.clear
      @context.freeze
      @chain.freeze
    end

    # @rbs () -> void
    def build_result
      @result = Result.new(
        task_id: @task_id,
        task_class: task_class,
        task_type: task_class.respond_to?(:type) ? task_class.type : Utils::Format.type_name(task_class),
        task_tags: task_class.task_settings.resolved_tags,
        state: @outcome.state,
        status: @outcome.status,
        reason: @outcome.reason,
        cause: @outcome.cause,
        metadata: @outcome.metadata,
        strict: @outcome.strict,
        retries: @outcome.retries,
        rolled_back: @outcome.rolled_back,
        context: @context,
        chain: @chain,
        errors: @errors,
        index: @chain.next_index
      )
    end

    # @rbs () -> void
    def invoke_status_callbacks
      type = :"on_#{@outcome.status}"
      invoke_callbacks(type)
      invoke_callbacks(@outcome.success? ? :on_good : :on_bad)
    end

    # @rbs () -> void
    def invoke_state_callbacks
      invoke_callbacks(@outcome.success? ? :on_complete : :on_interrupted)
      invoke_callbacks(:on_executed)
    end

    # @rbs (Symbol type) -> void
    def invoke_callbacks(type)
      task_class.callback_registry.invoke(type, @task, @result)
    end

    # @rbs () -> void
    def inject_result_for_callbacks!
      @task.instance_variable_set(:@_result, @result)
    end

    # @rbs () -> void
    def remove_result_from_task!
      @task.remove_instance_variable(:@_result) if @task.instance_variable_defined?(:@_result)
    end

    # @rbs () -> void
    def log_result!
      return unless @result

      @task.logger.info(@result.to_s)
    rescue StandardError
      nil
    end

    # @rbs () -> void
    def rollback!
      return unless @task.respond_to?(:rollback, true)
      return if @outcome.rolled_back

      @task.rollback
      @outcome.rolled_back = true
    rescue StandardError
      nil
    end

    # @rbs () -> void
    def raise_fault!
      klass = @outcome.failed? ? FailFault : SkipFault
      raise klass, @result
    end

  end
end

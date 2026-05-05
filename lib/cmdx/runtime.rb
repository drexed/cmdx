# frozen_string_literal: true

module CMDx
  # Orchestrates a task's full lifecycle: chain acquisition, middlewares,
  # telemetry, deprecation, callbacks, input resolution, `work` (wrapped in
  # retry), output verification, rollback on failure, result finalization,
  # and teardown (freeze + chain clear).
  #
  # Signal propagation: Runtime wraps `work` in `catch(Signal::TAG)` so
  # `success!` / `skip!` / `fail!` / `throw!` break out cleanly. Raised
  # Faults are converted to echoed signals (carrying the upstream failed
  # result as `:origin`); other `StandardError`s become failed signals with
  # the exception as `:cause`. `execute!` (strict mode) re-raises on failure
  # after the result is finalized, raising a {Fault} built from the deepest
  # originating result so `fault.task` points at the leaf that failed.
  #
  # @note Always used via the class method; never new Runtime manually.
  # @see Task.execute
  # @see Task.execute!
  class Runtime

    class << self

      # @param task [Task]
      # @param strict [Boolean] when true, re-raise on failure (`execute!` semantics)
      # @return [Result] the finalized, frozen result
      # @raise [Fault, StandardError] only when `strict: true` and the task failed
      def execute(task, strict: false)
        new(task, strict:).execute
      end

    end

    # @param task [Task]
    # @param strict [Boolean]
    def initialize(task, strict: false)
      @task   = task
      @strict = strict
    end

    # Runs the full lifecycle. Teardown runs in `ensure`, guaranteeing the
    # task's context/errors get frozen and the fiber chain is cleared even
    # when strict mode re-raises.
    #
    # @return [Result]
    # @raise [Fault, StandardError] under strict mode on failure
    def execute
      acquire_chain

      run_middlewares do
        emit_telemetry(:task_started)
        run_deprecation
        run_lifecycle
        finalize_result
        raise_signal! if @strict
      end

      @result
    ensure
      run_teardown
    end

    private

    def acquire_chain
      @root = Chain.current.nil?
      return unless @root

      xid = @task.class.settings.correlation_id&.call
      Chain.current = Chain.new(xid)
    end

    def run_middlewares(&)
      middlewares = @task.class.middlewares
      return yield if middlewares.empty?

      middlewares.process(@task, &)
    end

    def run_deprecation
      deprecation = @task.class.deprecation
      return unless deprecation

      deprecation.execute(@task) do
        @deprecated = true
        emit_telemetry(:task_deprecated)
      end
    end

    def run_lifecycle
      measure_duration do
        run_callbacks(:before_execution)
        run_callbacks(:before_validation)
        perform_work
        perform_rollback if @signal.failed?
        run_callbacks(:after_execution)
        run_callbacks(:"on_#{@signal.state}")
        run_callbacks(:"on_#{@signal.status}")
        run_callbacks(:on_ok) if @signal.ok?
        run_callbacks(:on_ko) if @signal.ko?
      end
    end

    def raise_signal!
      return unless @result.failed?

      cause = @signal.cause
      raise cause if cause && !cause.is_a?(Fault)

      raise Fault, @result.caused_failure
    end

    def finalize_result
      @result = Result.new(
        Chain.current,
        @task,
        @signal,
        root: @root,
        tid: @task.tid,
        strict: @strict,
        deprecated: @deprecated,
        rolled_back: @rolled_back,
        retries: @retries,
        duration: @duration
      ).tap do |result|
        @root ? Chain.current.unshift(result) : Chain.current.push(result)
        emit_telemetry(:task_executed, result:)
        @task.logger.info do
          exclusions = @task.class.settings.log_exclusions
          exclusions.empty? ? result : result.to_h.except(*exclusions)
        end
      end
    end

    def run_teardown
      @task.context.freeze if @root
      @task.errors.freeze
      @task.freeze
      return unless @root

      Chain.current.freeze
      Chain.clear
    end

    def measure_duration
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
      yield
    ensure
      @duration = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond) - start
    end

    def run_callbacks(event)
      callbacks = @task.class.callbacks
      return if callbacks.empty?

      callbacks.process(event, @task)
    end

    def perform_work
      @signal = catch(Signal::TAG) do
        resolve_inputs!
        retry_execution { @task.work }
        verify_outputs!
        Signal.success(nil, metadata: @task.metadata)
      rescue Fault => e
        Signal.echoed(e.result, cause: e, metadata: @task.metadata)
      rescue Error => e
        raise(e)
      rescue StandardError => e
        Signal.failed("[#{e.class}] #{e.message}", cause: e, metadata: @task.metadata)
      end
    end

    def perform_rollback
      return unless @task.respond_to?(:rollback)

      @rolled_back = true
      emit_telemetry(:task_rolled_back)
      @task.rollback
    end

    def resolve_inputs!
      inputs = @task.class.inputs
      return if inputs.empty?

      inputs.resolve(@task)
      signal_errors!
    end

    def retry_execution
      @task.class.retry_on.process(@task) do |attempt|
        @retries = attempt
        emit_telemetry(:task_retried, attempt:) if attempt.positive?
        yield
      end

      signal_errors!
    end

    def verify_outputs!
      outputs = @task.class.outputs
      return if outputs.empty?

      outputs.verify(@task)
      signal_errors!
    end

    def signal_errors!
      return if @task.errors.empty?

      throw(Signal::TAG, Signal.failed(@task.errors.to_s, metadata: @task.metadata))
    end

    def emit_telemetry(name, payload = EMPTY_HASH)
      telemetry = @task.class.telemetry
      return unless telemetry.subscribed?(name)

      event = Telemetry::Event.new(
        xid: Chain.current.xid,
        cid: Chain.current.id,
        root: @root,
        type: @task.class.type,
        task: @task.class,
        tid: @task.tid,
        name:,
        payload:,
        timestamp: Time.now.utc
      )

      telemetry.emit(name, event)
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Phases: middleware, validation, work, returns, callbacks, telemetry, freeze.
  class Executor

    STATE_CALLBACKS = {
      complete: :on_complete,
      interrupted: :on_interrupted
    }.freeze

    STATUS_CALLBACKS = {
      success: :on_success,
      skipped: :on_skipped,
      failed: :on_failed
    }.freeze

    # @param handler [Task]
    def initialize(handler)
      @handler = handler
    end

    # @param raise_on_fault [Boolean]
    # @return [ExecutionResult]
    def run(raise_on_fault: false)
      Deprecator.restrict(@handler)
      definition = Definition.fetch(@handler.class)
      trace = @handler.execution_trace || Trace.root(id_generator: CMDx.configuration.id_generator)
      logger = resolve_logger(definition)
      raw = @handler.raw_input_hash
      session = Session.new(definition:, handler: @handler, raw_input: raw, trace:, logger:)
      @handler.setup_session!(session)

      env = MiddlewareEnv.new(session:, handler: @handler)
      definition.middleware_stack.call(env) { inner_run(session) }

      verify_middleware_completed!(session)
      finalize!(session)
      result = ExecutionResult.new(session:, handler: @handler)

      raise_fault!(result, raise_on_fault:)
      result
    end

    private

    # @param definition [Definition]
    # @return [Logger]
    def resolve_logger(_definition)
      CMDx.configuration.logger
    end

    # @param session [Session]
    # @return [void]
    def inner_run(session)
      CallbackRunner.run(session, :before_validation)
      AttributePipeline.apply_all(session)

      if session.errors.empty?
        CallbackRunner.run(session, :before_execution)
        session.outcome.executing!
        catch(Outcome::HALT_TAG) do
          if session.definition.workflow
            WorkflowRunner.run(session)
          else
            session.handler.work
          end
        end
        verify_returns!(session) if session.outcome.success?
      else
        session.outcome.fail!(
          Locale.t("cmdx.faults.invalid"),
          halt: false,
          source: :validation,
          errors: session.errors.to_h
        )
      end
    rescue UndefinedMethodError => e
      session.handler.class.reset_cmdx_definition!
      raise e
    rescue CMDx::Fault => e
      raise e
    rescue StandardError => e
      retry if retry?(session, e)

      session.outcome.fail!(
        Utils::Normalize.exception(e),
        halt: false,
        cause: e,
        source: :exception
      )
      session.definition.exception_handler&.call(session.handler, e)
    ensure
      session.outcome.executed! if session.outcome.executing?
      post_execution_callbacks(session)
    end

    # @param session [Session]
    # @return [void]
    def verify_returns!(session)
      missing = session.definition.returns.reject { |k| session.context.key?(k) }
      return if missing.empty?

      missing.each { |name| session.errors.add(name, Locale.t("cmdx.returns.missing")) }
      session.outcome.fail!(
        Locale.t("cmdx.faults.invalid"),
        halt: false,
        source: :context,
        errors: session.errors.to_h
      )
    end

    # @param session [Session]
    # @return [void]
    def post_execution_callbacks(session)
      outcome = session.outcome
      return if session.definition.callbacks.values.all?(&:empty?)

      CallbackRunner.run(session, STATE_CALLBACKS[outcome.state]) if STATE_CALLBACKS.key?(outcome.state)
      CallbackRunner.run(session, :on_executed) if outcome.executed?
      CallbackRunner.run(session, STATUS_CALLBACKS[outcome.status]) if STATUS_CALLBACKS.key?(outcome.status)
      CallbackRunner.run(session, :on_good) if outcome.good?
      CallbackRunner.run(session, :on_bad) if outcome.bad?
    end

    # @param session [Session]
    # @return [void]
    def verify_middleware_completed!(session)
      return unless session.outcome.initialized?

      session.outcome.fail!(Locale.t("cmdx.faults.invalid"), halt: false, source: :middleware)
      session.outcome.executed!
    end

    # @param session [Session]
    # @return [void]
    def finalize!(session)
      emit_telemetry(session)
      log_backtrace(session) if session.definition.backtrace && session.outcome.failed?
      rollback_if_needed(session)
      freeze_all!(session)
    end

    # @param session [Session]
    # @return [void]
    def emit_telemetry(session)
      sink = CMDx.configuration.telemetry
      if sink.is_a?(Telemetry)
        sink.emit(:cmdx_execute, session.handler.to_h.merge(session.outcome.metadata))
      else
        session.logger.info { session.handler.to_h.merge(session.outcome.metadata).inspect }
      end
    end

    # @param session [Session]
    # @return [void]
    def log_backtrace(session)
      exc = session.outcome.cause
      return if exc.nil? || exc.is_a?(Fault)

      session.logger.error do
        Utils::Normalize.exception(exc) << "\n" << format_backtrace(session, exc)
      end
    end

    # @param session [Session]
    # @param exc [Exception]
    # @return [String]
    def format_backtrace(session, exc)
      if (cleaner = session.definition.backtrace_cleaner)
        cleaner.call(Array(exc.backtrace)).join("\n\t")
      else
        exc.full_message(highlight: false)
      end
    end

    # @param session [Session]
    # @return [void]
    def rollback_if_needed(session)
      return if session.outcome.rolled_back?
      return unless session.handler.respond_to?(:rollback)

      return unless session.definition.rollback_on.include?(session.outcome.status)

      session.outcome.rolled_back = true
      session.handler.rollback
    end

    # @param session [Session]
    # @return [void]
    def freeze_all!(session)
      return unless session.definition.freeze_results

      session.handler.freeze
      session.outcome.freeze
      session.context.freeze
    end

    # @param session [Session]
    # @param exception [Exception]
    # @return [Boolean]
    def retry?(session, exception)
      policy = session.definition.retry_policy
      return false if policy.nil? || !policy.retry_exception?(exception)
      return false unless session.outcome.retries < policy.max_attempts

      session.outcome.retries += 1
      session.errors.clear
      wait = policy.wait_seconds(session)
      CMDx.configuration.sleep_impl.call(wait) if wait.positive?
      true
    end

    # @param result [ExecutionResult]
    # @param raise_on_fault [Boolean]
    # @return [void]
    def raise_fault!(result, raise_on_fault:)
      return unless raise_on_fault
      return if result.success?

      bps = result.handler.class.definition.task_breakpoints
      return unless bps.include?(result.status)

      fault_class = result.skipped? ? SkipFault : FailFault
      raise fault_class, result
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Public object returned from {Task.execute}; read-only view of a finished run.
  class ExecutionResult

    extend Forwardable

    # @return [Session]
    attr_reader :session

    # @return [Task]
    attr_reader :handler

    def_delegators :session, :context, :outcome, :trace, :errors

    def_delegators :outcome, :state, :status, :reason, :metadata, :cause, :retries, :rolled_back?

    # @param session [Session]
    # @param handler [Task]
    def initialize(session:, handler:)
      @session = session
      @handler = handler
    end

    # @return [Task]
    alias task handler

    # @return [Trace] v1 called this +chain+
    alias chain trace

    # @return [Boolean]
    def success?
      outcome.complete? && outcome.success?
    end

    # @return [Boolean]
    def failed?
      outcome.interrupted? && outcome.failed?
    end

    # @return [Boolean]
    def skipped?
      outcome.interrupted? && outcome.skipped?
    end

    # @return [Boolean]
    def executed?
      outcome.executed?
    end

    # @return [Boolean]
    def good?
      !failed?
    end

    alias ok? good?

    # @return [Boolean]
    def bad?
      !success?
    end

    # @return [Symbol]
    def outcome_label
      if outcome.complete? || outcome.interrupted?
        outcome.status
      else
        outcome.state
      end
    end

    # @param states [Array<Symbol>]
    # @yieldparam self [ExecutionResult]
    # @return [self]
    def on(*states, &block)
      raise ArgumentError, "block required" unless block

      yield self if states.any? { |s| public_send(:"#{s}?") }
      self
    end

    # @return [Hash{Symbol => Object}]
    def to_h
      h = {
        trace_id: trace.id,
        type: handler.class.task_kind,
        class: handler.class.name,
        state: outcome.state,
        status: outcome.status,
        outcome: outcome_label,
        reason: outcome.reason,
        metadata: outcome.metadata.dup
      }
      h[:context] = context.to_h.dup if handler.class.definition.dump_context
      h
    end

  end
end

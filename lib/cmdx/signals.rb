# frozen_string_literal: true

module CMDx
  # Control flow methods mixed into Task.
  # Uses throw/catch for halting signals (3x faster than raise/rescue).
  module Signals

    # Signals success, optionally halting execution.
    #
    # @param reason [String, nil] success reason
    # @param halt [Boolean] whether to halt execution immediately
    # @param metadata [Hash] additional metadata
    #
    # @rbs (?String? reason, ?halt: bool, **untyped metadata) -> void
    def success!(reason = nil, halt: true, **metadata)
      raise "cannot annotate after interruption" if @_signal

      @_success = { reason:, metadata: }
      throw(:cmdx_signal, { status: :success, reason:, metadata: }) if halt
    end

    # Signals a skip, optionally halting execution.
    #
    # @param reason [String, nil] skip reason
    # @param halt [Boolean] whether to halt execution immediately
    # @param strict [Boolean] whether breakpoints apply
    # @param metadata [Hash] additional metadata
    #
    # @rbs (?String? reason, ?halt: bool, ?strict: bool, **untyped metadata) -> void
    def skip!(reason = nil, halt: true, strict: true, **metadata)
      return if @_signal

      signal = { status: :skipped, reason:, strict:, metadata: }
      halt ? throw(:cmdx_signal, signal) : (@_signal ||= signal)
    end

    # Signals a failure, optionally halting execution.
    #
    # @param reason [String, nil] failure reason
    # @param halt [Boolean] whether to halt execution immediately
    # @param strict [Boolean] whether breakpoints apply
    # @param metadata [Hash] additional metadata
    #
    # @rbs (?String? reason, ?halt: bool, ?strict: bool, **untyped metadata) -> void
    def fail!(reason = nil, halt: true, strict: true, **metadata)
      signal = { status: :failed, reason:, strict:, metadata: }
      halt ? throw(:cmdx_signal, signal) : (@_signal ||= signal)
    end

    # Re-throws another task's failure result into this execution.
    #
    # @param other_result [Result] the result to propagate
    # @param halt [Boolean] whether to halt execution immediately
    # @param metadata [Hash] additional metadata
    #
    # @rbs (Result other_result, ?halt: bool, **untyped metadata) -> void
    def throw!(other_result, halt: true, **metadata)
      signal = {
        status: other_result.status.to_sym,
        reason: other_result.reason,
        cause: other_result.cause,
        strict: other_result.strict?,
        metadata: (other_result.metadata || {}).merge(metadata),
        thrown_from: other_result.task_id
      }
      halt ? throw(:cmdx_signal, signal) : (@_signal ||= signal)
    end

    # Whether the current execution is a dry run.
    #
    # @return [Boolean]
    #
    # @rbs () -> bool
    def dry_run?
      !!context[:dry_run]
    end

  end
end

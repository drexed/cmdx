# frozen_string_literal: true

module CMDx
  # Internal halt token thrown by `success!`, `skip!`, `fail!`, and `throw!`
  # from inside a Task's `work`. Runtime catches `Signal::TAG` and converts the
  # payload into a {Result}. Not meant to be raised directly by user code.
  #
  # @see Runtime#perform_work
  # @see Task#success!
  # @see Task#fail!
  class Signal

    # `catch`/`throw` tag used by Runtime to intercept signal payloads.
    TAG = :cmdx_signal

    # All valid execution lifecycle states.
    STATES = [
      COMPLETE    = "complete",
      INTERRUPTED = "interrupted"
    ].freeze
    # All valid outcome statuses.
    STATUSES = [
      SUCCESS = "success",
      SKIPPED = "skipped",
      FAILED  = "failed"
    ].freeze

    class << self

      # Builds a successful signal (state `complete`, status `success`).
      #
      # @param reason [String, nil] optional human-readable reason
      # @param options [Hash{Symbol => Object}] optional `:metadata`, `:cause`, `:backtrace`
      # @option options [Hash{Symbol => Object}] :metadata merged onto the task metadata payload
      # @option options [Exception] :cause upstream exception when mirroring failures
      # @option options [Array<Thread::Backtrace::Location>] :backtrace captured frames
      # @return [Signal] new instance with frozen options
      def success(reason = nil, **options)
        new(COMPLETE, SUCCESS, **options, reason:)
      end

      # Builds a skipped signal (state `interrupted`, status `skipped`).
      #
      # @param reason [String, nil] optional human-readable reason
      # @param options [Hash{Symbol => Object}] optional `:metadata`, `:cause`, `:backtrace`
      # @option options [Hash{Symbol => Object}] :metadata merged onto the task metadata payload
      # @option options [Exception] :cause upstream exception when mirroring failures
      # @option options [Array<Thread::Backtrace::Location>] :backtrace captured frames
      # @return [Signal] new instance with frozen options
      def skipped(reason = nil, **options)
        new(INTERRUPTED, SKIPPED, **options, reason:)
      end

      # Builds a failed signal (state `interrupted`, status `failed`).
      #
      # @param reason [String, nil] optional human-readable reason
      # @param options [Hash{Symbol => Object}] optional `:metadata`, `:cause`, `:backtrace`
      # @option options [Hash{Symbol => Object}] :metadata merged onto the task metadata payload
      # @option options [Exception] :cause upstream exception when mirroring failures
      # @option options [Array<Thread::Backtrace::Location>] :backtrace captured frames
      # @return [Signal] new instance with frozen options
      def failed(reason = nil, **options)
        new(INTERRUPTED, FAILED, **options, reason:)
      end

      # Mirrors another Signal/Result's state + status with fresh options.
      # Used by Runtime to propagate a nested `Fault`'s outcome.
      #
      # @param other [Signal, Result] source to mirror state/status/reason from
      # @param options [Hash{Symbol => Object}] overrides: `:metadata`, `:cause`,
      #   `:backtrace`, `:origin`
      # @option options [Hash{Symbol => Object}] :metadata merged onto the task metadata payload
      # @option options [Exception] :cause upstream exception when mirroring failures
      # @option options [Array<Thread::Backtrace::Location>] :backtrace captured frames
      # @option options [Result] :origin peer result this signal echoes (set automatically for Results)
      # @return [Signal] new instance mirroring `other`
      # @raise [ArgumentError] when `other` is neither a Signal nor a Result
      def echoed(other, **options)
        raise ArgumentError, "Signal.echoed expected a Result or Signal (got #{other.class})" unless other.is_a?(Result) || other.is_a?(Signal)

        options[:origin] = other if other.is_a?(Result) && !options.key?(:origin)
        new(other.state, other.status, **options, reason: other.reason)
      end

    end

    attr_reader :state, :status

    # @param state [String] one of {STATES}
    # @param status [String] one of {STATUSES}
    # @param options [Hash{Symbol => Object}] frozen metadata payload
    # @option options [String] :reason
    # @option options [Hash] :metadata
    # @option options [Exception] :cause
    # @option options [Result] :origin
    # @option options [Array<Thread::Backtrace::Location>] :backtrace
    def initialize(state, status, **options)
      @state   = state
      @status  = status
      @options = options.freeze
    end

    # @return [Boolean] true when the task ran to completion without interruption
    def complete?
      state == COMPLETE
    end

    # @return [Boolean] true when skip/fail interrupted the task
    def interrupted?
      state == INTERRUPTED
    end

    # @return [Boolean]
    def success?
      status == SUCCESS
    end

    # @return [Boolean]
    def skipped?
      status == SKIPPED
    end

    # @return [Boolean]
    def failed?
      status == FAILED
    end

    # @return [Boolean] true for success or skipped (anything but failed)
    def ok?
      !failed?
    end

    # @return [Boolean] true for skipped or failed (anything but success)
    def ko?
      !success?
    end

    # @return [String, nil] human-readable explanation supplied by the caller
    def reason
      @options[:reason]
    end

    # @return [Hash{Symbol => Object}] frozen-empty hash when none was provided
    def metadata
      @options[:metadata] || EMPTY_HASH
    end

    # @return [Exception, nil] underlying exception when a rescue produced this signal
    def cause
      @options[:cause]
    end

    # @return [Result, nil] upstream result this signal was echoed from, when any
    def origin
      @options[:origin]
    end

    # @return [Array<Thread::Backtrace::Location>, nil] caller locations captured
    #   by `fail!` / `throw!` for Fault backtraces
    def backtrace
      @options[:backtrace]
    end

  end
end

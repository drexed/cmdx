# frozen_string_literal: true

module CMDx
  # Mutable state machine used internally by Runtime during execution.
  # Tracks lifecycle state and business status with guarded transitions.
  # Converted into a frozen {Result} after execution completes.
  class Outcome

    # @rbs HALT_TAG: Symbol
    HALT_TAG = :cmdx_signal

    STATES = %i[initialized executing complete interrupted].freeze
    STATUSES = %i[success skipped failed].freeze

    # @return [Symbol]
    attr_reader :state

    # @return [Symbol]
    attr_reader :status

    # @return [String, nil]
    attr_reader :reason

    # @return [Exception, nil]
    attr_reader :cause

    # @return [Hash{Symbol => Object}]
    attr_reader :metadata

    # @return [Integer]
    attr_accessor :retries

    # @return [Boolean]
    attr_accessor :rolled_back

    # @rbs () -> void
    def initialize
      @state = :initialized
      @status = :success
      @reason = nil
      @cause = nil
      @metadata = {}
      @retries = 0
      @rolled_back = false
    end

    # State predicates
    STATES.each { |s| define_method(:"#{s}?") { @state == s } }

    # Status predicates
    STATUSES.each { |s| define_method(:"#{s}?") { @status == s } }

    # @return [Boolean]
    #
    # @rbs () -> bool
    def executed?
      complete? || interrupted?
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def good?
      !failed?
    end
    alias ok? good?

    # @return [Boolean]
    #
    # @rbs () -> bool
    def bad?
      !success?
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def rolled_back?
      !!@rolled_back
    end

    # Transition: initialized -> executing
    #
    # @rbs () -> void
    def executing!
      return if executing?
      raise "cannot transition from #{@state} to executing" unless initialized?

      @state = :executing
    end

    # Transition: executing -> complete (only when successful)
    #
    # @rbs () -> void
    def complete!
      return if complete?
      raise "cannot transition from #{@state} to complete" unless executing?

      @state = :complete
    end

    # Transition: any non-complete -> interrupted
    #
    # @rbs () -> void
    def interrupt!
      return if interrupted?
      raise "cannot transition from #{@state} to interrupted" if complete?

      @state = :interrupted
    end

    # Convenience: complete if success, interrupt otherwise.
    #
    # @rbs () -> void
    def finalize_state!
      success? ? complete! : interrupt!
    end

    # Applies a signal hash thrown by task signal methods.
    #
    # @param signal [Hash, nil]
    #
    # @rbs (Hash[Symbol, untyped]? signal) -> void
    def apply_signal(signal)
      return unless signal

      self.status = signal[:status].to_s if signal[:status]
      @reason = signal[:reason] || Locale.t("cmdx.reasons.unspecified") unless success?
      @cause = signal[:cause] if signal.key?(:cause)
      @metadata.merge!(signal[:metadata] || {})
      @metadata[:strict] = signal.fetch(:strict, true)
      @metadata[:thrown_from] = signal[:thrown_from] if signal.key?(:thrown_from)
    end

    # Marks failure with a reason and optional cause.
    #
    # @rbs (?String? reason, ?cause: Exception?, **untyped meta) -> void
    def fail!(reason = nil, cause: nil, **meta)
      return if failed?

      @status = :failed
      @state = :interrupted
      @reason = reason || Locale.t("cmdx.reasons.unspecified")
      @cause = cause
      @metadata.merge!(meta)
    end

    # @rbs (Hash[Symbol, Object] hash) -> void
    def merge_metadata!(hash)
      @metadata.merge!(hash)
    end

    # @return [self]
    #
    # @rbs () -> self
    def freeze
      @metadata.freeze
      super
    end

    private

    # @rbs (String | Symbol value) -> void
    def status=(value)
      @status = value.to_sym
    end

  end
end

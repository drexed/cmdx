# frozen_string_literal: true

module CMDx

  # Mutable scratch pad used by the Runtime to track execution state.
  # Converted into an immutable Result after execution completes.
  #
  # @!attribute state
  #   @return [Symbol] current lifecycle state
  # @!attribute status
  #   @return [Symbol] business outcome status
  # @!attribute reason
  #   @return [String, nil] interruption reason
  # @!attribute cause
  #   @return [Exception, nil] causing exception
  # @!attribute metadata
  #   @return [Hash] additional execution data
  # @!attribute strict
  #   @return [Boolean] whether breakpoints apply
  # @!attribute retries
  #   @return [Integer] retry attempt count
  # @!attribute rolled_back
  #   @return [Boolean] whether rollback was performed
  Outcome = Struct.new(
    :state, :status, :reason, :cause, :metadata,
    :strict, :retries, :rolled_back,
    keyword_init: true
  ) do
    def initialize(**)
      super
      self.state ||= "initialized"
      self.status ||= "success"
      self.metadata ||= {}
      self.strict = true if strict.nil?
      self.retries ||= 0
      self.rolled_back ||= false
    end

    # @rbs () -> bool
    def success?
      status == "success"
    end

    # @rbs () -> bool
    def failed?
      status == "failed"
    end

    # @rbs () -> bool
    def skipped?
      status == "skipped"
    end

    # Applies a signal hash from throw/catch control flow.
    #
    # @param signal [Hash] signal data from Task control flow methods
    #
    # @rbs (Hash[Symbol, untyped] signal) -> void
    def apply_signal(signal)
      return unless signal

      self.status = signal[:status].to_s if signal[:status]
      self.reason = signal[:reason] || Locale.t("cmdx.reasons.unspecified") unless success?
      self.cause = signal[:cause] if signal.key?(:cause)
      self.strict = signal.fetch(:strict, true)
      self.metadata = metadata.merge(signal[:metadata] || {})
    end
  end

end

# frozen_string_literal: true

module CMDx
  # Structured observability hook. Emits named events with payloads.
  # Configurable via +CMDx.configuration.telemetry+.
  class Telemetry

    # @return [Logger]
    attr_reader :logger

    # @return [Proc, nil]
    attr_reader :redact

    # @param logger [Logger]
    # @param redact [Proc, nil] transforms payload to strip secrets
    #
    # @rbs (logger: Logger, ?redact: Proc?) -> void
    def initialize(logger:, redact: nil)
      @logger = logger
      @redact = redact
    end

    # Emits a named event with an optional payload.
    #
    # @param name [Symbol, String]
    # @param payload [Hash]
    #
    # @rbs (Symbol | String name, Hash[Symbol, untyped] payload) -> void
    def emit(name, payload = {})
      data = @redact ? @redact.call(payload) : payload
      @logger.info { "[CMDx::Telemetry] #{name} #{data.inspect}" }
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Structured observability hook; default implementation logs via +Logger+.
  class Telemetry

    # @param logger [Logger]
    # @param redact [Proc, nil] +(payload) -> payload+ with secrets stripped
    def initialize(logger:, redact: nil)
      @logger = logger
      @redact = redact
    end

    # @param name [Symbol]
    # @param payload [Hash]
    # @return [void]
    def emit(name, payload)
      data = @redact ? @redact.call(payload) : payload
      @logger.info { "#{name} #{data.inspect}" }
    end

  end
end

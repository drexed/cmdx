# frozen_string_literal: true

module CMDx
  # One execution of a handler: holds context, outcome, trace, and raw input.
  class Session

    # @return [Definition]
    attr_reader :definition

    # @return [Task]
    attr_reader :handler

    # @return [Context]
    attr_reader :context

    # @return [Errors]
    attr_reader :errors

    # @return [Outcome]
    attr_reader :outcome

    # @return [Trace]
    attr_reader :trace

    # @return [Hash{Symbol => Object}]
    attr_reader :raw_input

    # @return [Logger]
    attr_reader :logger

    # @param definition [Definition]
    # @param handler [Task]
    # @param raw_input [Hash]
    # @param trace [Trace]
    # @param logger [Logger]
    def initialize(definition:, handler:, raw_input:, trace:, logger:)
      @definition = definition
      @handler = handler
      @raw_input = raw_input.transform_keys(&:to_sym).freeze
      @trace = trace
      @errors = Errors.new
      @outcome = Outcome.new
      @context = Context.build(raw_input)
      @logger = logger
    end

    # @return [Telemetry, Logger]
    def telemetry
      CMDx.configuration.telemetry || CMDx.configuration.logger
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Encapsulates all mutable state for a single task execution.
  # Created by Runtime, never exposed to the user.
  class Session

    # @return [Definition]
    attr_reader :definition

    # @return [Context]
    attr_reader :context

    # @return [Outcome]
    attr_reader :outcome

    # @return [Errors]
    attr_reader :errors

    # @return [Trace]
    attr_reader :trace

    # @return [Logger]
    attr_reader :logger

    # @return [Hash{Symbol => Object}] raw symbolized input
    attr_reader :raw_input

    # @param definition [Definition]
    # @param args [Hash]
    # @param trace [Trace, nil]
    #
    # @rbs (Definition definition, Hash[Symbol, untyped] args, ?Trace? trace) -> void
    def initialize(definition, args, trace = nil)
      @definition = definition
      @raw_input = args.transform_keys(&:to_sym).freeze
      @context = Context.build(@raw_input.dup)
      @outcome = Outcome.new
      @errors = Errors.new
      @trace = trace || Trace.root
      @logger = resolve_logger(definition)
    end

    private

    # @rbs (Definition definition) -> Logger
    def resolve_logger(definition)
      base = definition.logger || CMDx.configuration.logger
      level = definition.log_level || CMDx.configuration.log_level
      base.level = level if base.respond_to?(:level=)
      base
    end

  end
end

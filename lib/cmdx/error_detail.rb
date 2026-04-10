# frozen_string_literal: true

module CMDx
  # A single structured error entry for an attribute.
  class ErrorDetail

    # @return [Symbol]
    attr_reader :attribute

    # @return [String]
    attr_reader :message

    # @return [Symbol, nil]
    attr_reader :code

    # @param attribute [Symbol]
    # @param message [String]
    # @param code [Symbol, nil]
    #
    # @rbs (Symbol attribute, String message, ?Symbol? code) -> void
    def initialize(attribute, message, code = nil)
      @attribute = attribute.to_sym
      @message = message.to_s
      @code = code
    end

    # @return [String]
    #
    # @rbs () -> String
    def full_message
      "#{attribute} #{message}"
    end

    # @return [Hash]
    #
    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      h = { attribute:, message: }
      h[:code] = code if code
      h
    end

  end
end

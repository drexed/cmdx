# frozen_string_literal: true

module CMDx
  # Single validation or attribute error entry.
  #
  # @!attribute [r] attribute
  #   @return [Symbol]
  # @!attribute [r] message
  #   @return [String]
  # @!attribute [r] code
  #   @return [Symbol, nil]
  class ErrorDetail

    attr_reader :attribute, :message, :code

    # @param attribute [Symbol]
    # @param message [String]
    # @param code [Symbol, nil]
    def initialize(attribute, message, code = nil)
      @attribute = attribute.to_sym
      @message = message.to_s
      @code = code
    end

    # @return [String]
    def full_message
      "#{attribute} #{message}"
    end

  end
end

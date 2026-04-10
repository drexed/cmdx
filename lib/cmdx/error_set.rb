# frozen_string_literal: true

module CMDx
  # Collection of validation error messages keyed by attribute name.
  class ErrorSet

    def initialize
      @errors = {}
    end

    # @param attribute [Symbol] the attribute name
    # @param message [String] the error message
    # @return [void]
    def add(attribute, message)
      (@errors[attribute.to_sym] ||= []) << message
    end

    # @return [Boolean]
    def any?
      !@errors.empty?
    end

    # @return [Boolean]
    def empty?
      @errors.empty?
    end

    # @return [Integer] number of attributes with errors
    def size
      @errors.size
    end

    # @param attribute [Symbol]
    # @return [Boolean]
    def for?(attribute)
      @errors.key?(attribute.to_sym)
    end

    # @return [Hash<Symbol, Array<String>>]
    def to_h
      @errors.dup
    end

    # @return [Hash<Symbol, Array<String>>] messages prefixed with attribute name
    def full_messages
      @errors.each_with_object({}) do |(attr, msgs), hash|
        hash[attr] = msgs.map { |m| "#{attr} #{m}" }
      end
    end

    # @return [String] all full messages joined by ". "
    def to_s
      full_messages.values.flatten.join(". ")
    end

    # Clear all errors.
    # @return [void]
    def clear
      @errors.clear
    end

    def freeze
      @errors.freeze
      super
    end

    def inspect
      "#<#{self.class} #{@errors.inspect}>"
    end

  end
end

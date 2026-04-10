# frozen_string_literal: true

module CMDx
  # Structured errors keyed by attribute, with optional codes.
  class Errors

    # @return [Array<ErrorDetail>]
    attr_reader :details

    def initialize
      @details = []
    end

    # @param attribute [Symbol]
    # @param message [String]
    # @param code [Symbol, nil]
    # @return [void]
    def add(attribute, message, code = nil)
      return if message.nil? || message.empty?

      @details << ErrorDetail.new(attribute, message, code)
    end

    # @return [Boolean]
    def empty?
      @details.empty?
    end

    # @return [Boolean]
    def any?
      !empty?
    end

    # @return [void]
    def clear
      @details.clear
    end

    # @param attribute [Symbol]
    # @return [Boolean]
    def for?(attribute)
      sym = attribute.to_sym
      @details.any? { |d| d.attribute == sym }
    end

    # @return [Hash{Symbol => Array<String>}]
    def to_h
      @details.group_by(&:attribute).transform_values { |list| list.map(&:message) }
    end

    # @return [String]
    def to_s
      @details.map(&:full_message).join(", ")
    end

  end
end

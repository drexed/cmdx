# frozen_string_literal: true

module CMDx
  # Structured collection of validation and execution errors.
  # Stores {ErrorDetail} entries keyed by attribute name.
  class Errors

    include Enumerable

    # @rbs () -> void
    def initialize
      @store = Hash.new { |h, k| h[k] = [] }
    end

    # @param attribute [Symbol, String] attribute name (dot-separated for nested)
    # @param message [String]
    # @param code [Symbol, nil]
    # @return [ErrorDetail]
    #
    # @rbs (Symbol | String attribute, String message, ?Symbol? code) -> ErrorDetail
    def add(attribute, message, code = nil)
      detail = ErrorDetail.new(attribute, message, code)
      @store[attribute.to_sym] << detail
      detail
    end

    # @param attribute [Symbol]
    # @return [Array<ErrorDetail>]
    #
    # @rbs (Symbol attribute) -> Array[ErrorDetail]
    def [](attribute)
      @store[attribute.to_sym]
    end

    # @rbs () { (ErrorDetail) -> void } -> Enumerator[ErrorDetail, void]
    def each(&)
      @store.each_value { |details| details.each(&) }
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def any?
      @store.any? { |_, v| v.any? }
    end

    # @return [Boolean]
    #
    # @rbs () -> bool
    def empty?
      !any?
    end

    # @return [Array<String>]
    #
    # @rbs () -> Array[String]
    def full_messages
      flat_map(&:full_message)
    end

    # @return [Hash{Symbol => Array<String>}]
    #
    # @rbs () -> Hash[Symbol, Array[String]]
    def to_h
      @store.transform_values { |details| details.map(&:message) }
    end

    # @return [String]
    #
    # @rbs () -> String
    def to_s
      full_messages.join(", ")
    end

    # @return [self]
    #
    # @rbs () -> self
    def freeze
      @store.each_value(&:freeze)
      @store.freeze
      super
    end

    # @return [void]
    #
    # @rbs () -> void
    def clear
      @store.clear
    end

  end
end

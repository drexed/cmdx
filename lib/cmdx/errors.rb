# frozen_string_literal: true

module CMDx
  # Collection of validation and execution errors organized by attribute.
  # Provides methods to add, query, and format error messages.
  class Errors

    # @return [Hash{Symbol => Set<String>}] error messages keyed by attribute
    #
    # @rbs @messages: Hash[Symbol, Set[String]]
    attr_reader :messages

    # @rbs () -> void
    def initialize
      @messages = {}
    end

    # @param attribute [Symbol] the attribute name
    # @param message [String] the error message
    #
    # @rbs (Symbol attribute, String message) -> void
    def add(attribute, message)
      return if message.empty?

      messages[attribute] ||= Set.new
      messages[attribute] << message
    end

    # @param attribute [Symbol] the attribute to check
    #
    # @return [Boolean] true if the attribute has errors
    #
    # @rbs (Symbol attribute) -> bool
    def for?(attribute)
      set = messages[attribute]
      !set.nil? && !set.empty?
    end

    # @return [Boolean] true if there are no errors
    #
    # @rbs () -> bool
    def empty?
      messages.empty?
    end

    # @return [Boolean] true if there are any errors
    #
    # @rbs () -> bool
    def any?
      !empty?
    end

    # @return [Integer] the number of attributes with errors
    #
    # @rbs () -> Integer
    def size
      messages.size
    end

    # Removes all errors.
    #
    # @rbs () -> void
    def clear
      messages.clear
    end

    # @return [Hash{Symbol => Array<String>}] full messages with attribute names
    #
    # @rbs () -> Hash[Symbol, Array[String]]
    def full_messages
      messages.each_with_object({}) do |(attribute, msgs), hash|
        hash[attribute] = msgs.map { |m| "#{attribute} #{m}" }
      end
    end

    # @return [Hash{Symbol => Array<String>}] messages without attribute names
    #
    # @rbs () -> Hash[Symbol, Array[String]]
    def to_h
      messages.transform_values(&:to_a)
    end

    # @param full [Boolean] whether to include attribute names
    #
    # @return [Hash{Symbol => Array<String>}]
    #
    # @rbs (?bool full) -> Hash[Symbol, Array[String]]
    def to_hash(full = false)
      full ? full_messages : to_h
    end

    # @return [String] human-readable error summary
    #
    # @rbs () -> String
    def to_s
      full_messages.values.flatten.join(". ")
    end

  end
end

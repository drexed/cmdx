# frozen_string_literal: true

module CMDx
  # Collection of validation and execution errors organized by attribute.
  # Provides methods to add, query, and format error messages for different
  # attributes in a task or workflow execution.
  class Errors

    extend Forwardable

    attr_reader :messages

    def_delegators :messages, :empty?

    # Initialize a new error collection.
    def initialize
      @messages = {}
    end

    # Add an error message for a specific attribute.
    #
    # @param attribute [Symbol] The attribute name associated with the error
    # @param message [String] The error message to add
    #
    # @example
    #   errors = CMDx::Errors.new
    #   errors.add(:email, "must be valid format")
    #   errors.add(:email, "cannot be blank")
    def add(attribute, message)
      return if message.empty?

      messages[attribute] ||= Set.new
      messages[attribute] << message
    end

    # Check if there are any errors for a specific attribute.
    #
    # @param attribute [Symbol] The attribute name to check for errors
    #
    # @return [Boolean] true if the attribute has errors, false otherwise
    #
    # @example
    #   errors.for?(:email) # => true
    #   errors.for?(:name)  # => false
    def for?(attribute)
      return false unless messages.key?(attribute)

      !messages[attribute].empty?
    end

    # Convert errors to a hash format with arrays of full messages.
    #
    # @return [Hash{Symbol => Array<String>}] Hash with attribute keys and message arrays
    #
    # @example
    #   errors.full_messages # => { email: ["email must be valid format", "email cannot be blank"] }
    def full_messages
      messages.each_with_object({}) do |(attribute, messages), hash|
        hash[attribute] = messages.map { |message| "#{attribute} #{message}" }
      end
    end

    # Convert errors to a hash format with arrays of messages.
    #
    # @return [Hash{Symbol => Array<String>}] Hash with attribute keys and message arrays
    #
    # @example
    #   errors.to_h # => { email: ["must be valid format", "cannot be blank"] }
    def to_h
      messages.transform_values(&:to_a)
    end

    # Convert errors to a hash format with optional full messages.
    #
    # @param full [Boolean] Whether to include full messages with attribute names
    # @return [Hash{Symbol => Array<String>}] Hash with attribute keys and message arrays
    #
    # @example
    #   errors.to_hash # => { email: ["must be valid format", "cannot be blank"] }
    #   errors.to_hash(true) # => { email: ["email must be valid format", "email cannot be blank"] }
    def to_hash(full = false)
      full ? full_messages : to_h
    end

    # Convert errors to a human-readable string format.
    #
    # @return [String] Formatted error messages joined with periods
    #
    # @example
    #   errors.to_s # => "email must be valid format. email cannot be blank"
    def to_s
      full_messages.values.flatten.join(". ")
    end

  end
end

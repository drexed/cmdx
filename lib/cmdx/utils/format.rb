# frozen_string_literal: true

module CMDx
  module Utils
    # Utility module for formatting data structures into log-friendly strings
    # and converting messages to appropriate formats for logging
    module Format

      extend self

      # @rbs FORMATTER: Proc
      FORMATTER = proc do |key, value|
        "#{key}=#{value.inspect}"
      end.freeze
      private_constant :FORMATTER

      # Converts a message to a format suitable for logging
      #
      # @param message [Object] The message to format
      #
      # @return [Hash, Object] Returns a hash if the message responds to to_h and is a CMDx object, otherwise returns the original message
      #
      # @example Hash like objects
      #   Format.to_log({user_id: 123, action: "login"})
      #   # => {user_id: 123, action: "login"}
      # @example Simple message
      #   Format.to_log("simple message")
      #   # => "simple message"
      # @example CMDx object
      #   Format.to_log(CMDx::Task.new(name: "task1"))
      #   # => {name: "task1"}
      #
      # @rbs (untyped message) -> untyped
      def to_log(message)
        if message.respond_to?(:to_h) && cmdx_based_object?(message.class)
          message.to_h
        else
          message
        end
      end

      # Converts a hash to a formatted string using a custom formatter
      #
      # @param hash [Hash] The hash to convert to string
      # @param block [Proc, nil] Optional custom formatter block
      # @option block [String] :key The hash key
      # @option block [Object] :value The hash value
      #
      # @return [String] Space-separated formatted key-value pairs
      #
      # @example Default formatter
      #   Format.to_str({user_id: 123, status: "active"})
      #   # => "user_id=123 status=\"active\""
      # @example Custom formatter
      #   Format.to_str({count: 5, total: 100}) { |k, v| "#{k}:#{v}" }
      #   # => "count:5 total:100"
      #
      # @rbs (Hash[untyped, untyped] hash) ?{ (untyped, untyped) -> String } -> String
      def to_str(hash, &block)
        block ||= FORMATTER
        hash.map(&block).join(" ")
      end

      private

      # Checks if a class belongs to the CMDx namespace, caching per class.
      #
      # @param klass [Class] The class to check
      #
      # @return [Boolean] true if the class is in the CMDx namespace
      #
      # @rbs (Class klass) -> bool
      def cmdx_based_object?(klass)
        @cmdx_classes ||= {}
        return @cmdx_classes[klass] if @cmdx_classes.key?(klass)

        @cmdx_classes[klass] = klass.ancestors.any? { |a| a.name&.start_with?("CMDx::") }
      end

    end
  end
end

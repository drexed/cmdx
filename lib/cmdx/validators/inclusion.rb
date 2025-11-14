# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is included in a specified set or range
    #
    # This validator ensures that the given value is present within a collection
    # of allowed values or falls within a specified range. It supports both
    # discrete value lists and range-based validations.
    module Inclusion

      extend self

      # Validates that a value is included in the specified options
      #
      # @param value [Object] The value to validate for inclusion
      # @param options [Hash] Validation configuration options
      # @option options [Array, Range] :in The collection of allowed values or range
      # @option options [Array, Range] :within Alias for :in option
      # @option options [String] :message Custom error message template
      # @option options [String] :of_message Custom message for discrete value inclusions
      # @option options [String] :in_message Custom message for range-based inclusions
      # @option options [String] :within_message Custom message for range-based inclusions
      #
      # @return [nil] Returns nil if validation passes
      #
      # @raise [ValidationError] When the value is not found in the allowed collection
      #
      # @example Include specific values
      #   Inclusion.call("admin", in: ["admin", "user", "guest"])
      #   # => nil (validation passes)
      # @example Include values within a range
      #   Inclusion.call(5, in: 1..10)
      #   # => nil (validation passes - 5 is within 1..10)
      # @example Include with custom message
      #   Inclusion.call("test", in: ["admin", "user"], message: "must be one of: %{values}")
      #
      # @rbs (untyped value, Hash[Symbol, untyped] options) -> nil
      def call(value, options = {})
        values = options[:in] || options[:within]

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) unless values.cover?(value)
        elsif Array(values).none? { |v| v === value }
          raise_of_validation_error!(values, options)
        end
      end

      private

      # Raises validation error for discrete value inclusions
      #
      # @param values [Array] The allowed values that caused the error
      # @param options [Hash] Validation options containing custom messages
      # @option options [Object] :* Any validation option key-value pairs
      #
      # @raise [ValidationError] With appropriate error message
      def raise_of_validation_error!(values, options)
        values = values.map(&:inspect).join(", ") unless values.nil?
        message = options[:of_message] || options[:message]
        message %= { values: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.inclusion.of", values:)
      end

      # Raises validation error for range-based inclusions
      #
      # @param min [Object] The minimum value of the allowed range
      # @param max [Object] The maximum value of the allowed range
      # @param options [Hash] Validation options containing custom messages
      # @option options [Object] :* Any validation option key-value pairs
      #
      # @raise [ValidationError] With appropriate error message
      def raise_within_validation_error!(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.inclusion.within", min:, max:)
      end

    end
  end
end

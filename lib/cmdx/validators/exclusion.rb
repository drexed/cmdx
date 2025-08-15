# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is not included in a specified set or range
    #
    # This validator ensures that the given value is excluded from a collection
    # of forbidden values or falls outside a specified range. It supports both
    # discrete value lists and range-based exclusions.
    module Exclusion

      extend self

      # Validates that a value is excluded from the specified options
      #
      # @param value [Object] The value to validate for exclusion
      # @param options [Hash] Validation configuration options
      # @option options [Array, Range] :in The collection of forbidden values or range
      # @option options [Array, Range] :within Alias for :in option
      # @option options [String] :message Custom error message template
      # @option options [String] :of_message Custom message for discrete value exclusions
      # @option options [String] :in_message Custom message for range-based exclusions
      # @option options [String] :within_message Custom message for range-based exclusions
      #
      # @return [void]
      #
      # @raise [ValidationError] When the value is found in the forbidden collection
      #
      # @example Exclude specific values
      #   Exclusion.call("admin", in: ["admin", "root", "superuser"])
      #   # => raises ValidationError if value is "admin"
      # @example Exclude values within a range
      #   Exclusion.call(5, in: 1..10)
      #   # => raises ValidationError if value is 5 (within 1..10)
      # @example Exclude with custom message
      #   Exclusion.call("test", in: ["test", "demo"], message: "value %{values} is forbidden")
      def call(value, options = {})
        values = options[:in] || options[:within]

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) if values.cover?(value)
        elsif Array(values).any? { |v| v === value }
          raise_of_validation_error!(values, options)
        end
      end

      private

      # Raises validation error for discrete value exclusions
      #
      # @param values [Array] The forbidden values that caused the error
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      def raise_of_validation_error!(values, options)
        values = values.map(&:inspect).join(", ") unless values.nil?
        message = options[:of_message] || options[:message]
        message %= { values: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.exclusion.of", values:)
      end

      # Raises validation error for range-based exclusions
      #
      # @param min [Object] The minimum value of the forbidden range
      # @param max [Object] The maximum value of the forbidden range
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      def raise_within_validation_error!(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.exclusion.within", min:, max:)
      end

    end
  end
end

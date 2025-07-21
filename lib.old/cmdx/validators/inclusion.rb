# frozen_string_literal: true

module CMDx
  module Validators
    # Validator class for including values within a specified set.
    #
    # This validator ensures that a value is included in a given array or range
    # of allowed values. It supports both discrete value inclusion and range-based
    # inclusion validation.
    class Inclusion < Validator

      # Validates that the given value is included in the inclusion set.
      #
      # @param value [Object] the value to validate
      # @param options [Hash] validation options containing inclusion configuration
      # @option options [Hash] :inclusion inclusion validation configuration
      # @option options [Array, Range] :inclusion.in the values to include
      # @option options [Array, Range] :inclusion.within alias for :in
      # @option options [String] :inclusion.message custom error message
      # @option options [String] :inclusion.of_message custom error message for array inclusion
      # @option options [String] :inclusion.in_message custom error message for range inclusion
      # @option options [String] :inclusion.within_message alias for :in_message
      #
      # @return [void]
      #
      # @raise [ValidationError] if the value is not found in the inclusion set
      #
      # @example Including from an array
      #   Validators::Inclusion.call("user", inclusion: { in: ["user", "admin"] })
      #   #=> nil (no error raised)
      #
      # @example Including from a range
      #   Validators::Inclusion.call(5, inclusion: { in: 1..10 })
      #   #=> nil (no error raised)
      #
      # @example Invalid inclusion from array
      #   Validators::Inclusion.call("guest", inclusion: { in: ["user", "admin"] })
      #   # raises ValidationError: "must be one of: \"user\", \"admin\""
      #
      # @example Invalid inclusion from range
      #   Validators::Inclusion.call(15, inclusion: { in: 1..10 })
      #   # raises ValidationError: "must be within 1 and 10"
      #
      # @example Using a custom message
      #   Validators::Inclusion.call("guest", inclusion: { in: ["user", "admin"], message: "Invalid role selected" })
      #   # raises ValidationError: "Invalid role selected"
      def call(value, options = {})
        values = options[:in] || options[:within]

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) unless values.cover?(value)
        elsif Array(values).none? { |v| v === value } # rubocop:disable Style/CaseEquality
          raise_of_validation_error!(values, options)
        end
      end

      private

      # Raises a validation error for array-based inclusion.
      #
      # @param values [Array] the allowed values
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_of_validation_error!(["user", "admin"], {})
      #   # raises ValidationError: "must be one of: \"user\", \"admin\""
      def raise_of_validation_error!(values, options)
        values  = values.map(&:inspect).join(", ") unless values.nil?
        message = options[:of_message] || options[:message]
        message %= { values: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.inclusion.of",
          values:,
          default: "must be one of: #{values}"
        )
      end

      # Raises a validation error for range-based inclusion.
      #
      # @param min [Object] the minimum value of the range
      # @param max [Object] the maximum value of the range
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_within_validation_error!(1, 10, {})
      #   # raises ValidationError: "must be within 1 and 10"
      def raise_within_validation_error!(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.inclusion.within",
          min:,
          max:,
          default: "must be within #{min} and #{max}"
        )
      end

    end
  end
end

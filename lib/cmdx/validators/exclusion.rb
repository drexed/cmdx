# frozen_string_literal: true

module CMDx
  module Validators
    # Validator class for excluding values from a specified set.
    #
    # This validator ensures that a value is not included in a given array or range
    # of forbidden values. It supports both discrete value exclusion and range-based
    # exclusion validation.
    #
    # @since 1.0.0
    class Exclusion < Validator

      # Validates that the given value is not included in the exclusion set.
      #
      # @param value [Object] the value to validate
      # @param options [Hash] validation options containing exclusion configuration
      # @option options [Hash] :exclusion exclusion validation configuration
      # @option options [Array, Range] :exclusion.in the values to exclude
      # @option options [Array, Range] :exclusion.within alias for :in
      # @option options [String] :exclusion.message custom error message
      # @option options [String] :exclusion.of_message custom error message for array exclusion
      # @option options [String] :exclusion.in_message custom error message for range exclusion
      # @option options [String] :exclusion.within_message alias for :in_message
      #
      # @return [void]
      #
      # @raise [ValidationError] if the value is found in the exclusion set
      #
      # @example Excluding from an array
      #   Validators::Exclusion.call("admin", exclusion: { in: ["admin", "root"] })
      #   # raises ValidationError: "must not be one of: \"admin\", \"root\""
      #
      # @example Excluding from a range
      #   Validators::Exclusion.call(5, exclusion: { in: 1..10 })
      #   # raises ValidationError: "must not be within 1 and 10"
      #
      # @example Valid exclusion
      #   Validators::Exclusion.call("user", exclusion: { in: ["admin", "root"] })
      #   # => nil (no error raised)
      #
      # @example Using a custom message
      #   Validators::Exclusion.call("admin", exclusion: { in: ["admin", "root"], message: "Reserved username not allowed" })
      #   # raises ValidationError: "Reserved username not allowed"
      def call(value, options = {})
        values = options.dig(:exclusion, :in) ||
                 options.dig(:exclusion, :within)

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) if values.cover?(value)
        elsif Array(values).any? { |v| v === value } # rubocop:disable Style/CaseEquality
          raise_of_validation_error!(values, options)
        end
      end

      private

      # Raises a validation error for array-based exclusion.
      #
      # @param values [Array] the excluded values
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_of_validation_error!(["admin", "root"], {})
      #   # raises ValidationError: "must not be one of: \"admin\", \"root\""
      def raise_of_validation_error!(values, options)
        values  = values.map(&:inspect).join(", ")
        message = options.dig(:exclusion, :of_message) ||
                  options.dig(:exclusion, :message)
        message %= { values: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.exclusion.of",
          values:,
          default: "must not be one of: #{values}"
        )
      end

      # Raises a validation error for range-based exclusion.
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
      #   # raises ValidationError: "must not be within 1 and 10"
      def raise_within_validation_error!(min, max, options)
        message = options.dig(:exclusion, :in_message) ||
                  options.dig(:exclusion, :within_message) ||
                  options.dig(:exclusion, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.exclusion.within",
          min:,
          max:,
          default: "must not be within #{min} and #{max}"
        )
      end

    end
  end
end

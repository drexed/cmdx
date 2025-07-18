# frozen_string_literal: true

module CMDx
  module Validators
    # Validator class for validating numeric values with various constraints.
    #
    # This validator ensures that numeric values meet specified criteria such as
    # being within a range, having minimum/maximum values, or matching exact values.
    # It supports both inclusive and exclusive range validation, as well as discrete
    # value matching and rejection.
    class Numeric < Validator

      # Validates that the given numeric value meets the specified constraints.
      #
      # @param value [Numeric] the numeric value to validate
      # @param options [Hash] validation options containing numeric configuration
      # @option options [Hash] :numeric numeric validation configuration
      # @option options [Range] :numeric.within the range the value must be within
      # @option options [Range] :numeric.not_within the range the value must not be within
      # @option options [Range] :numeric.in alias for :within
      # @option options [Range] :numeric.not_in alias for :not_within
      # @option options [Numeric] :numeric.min the minimum allowed value (can be combined with :max)
      # @option options [Numeric] :numeric.max the maximum allowed value (can be combined with :min)
      # @option options [Numeric] :numeric.is the exact value required
      # @option options [Numeric] :numeric.is_not the exact value that is not allowed
      # @option options [String] :numeric.message custom error message for any validation
      # @option options [String] :numeric.within_message custom error message for within validation
      # @option options [String] :numeric.in_message alias for :within_message
      # @option options [String] :numeric.not_within_message custom error message for not_within validation
      # @option options [String] :numeric.not_in_message alias for :not_within_message
      # @option options [String] :numeric.min_message custom error message for min validation
      # @option options [String] :numeric.max_message custom error message for max validation
      # @option options [String] :numeric.is_message custom error message for is validation
      # @option options [String] :numeric.is_not_message custom error message for is_not validation
      #
      # @return [void]
      #
      # @raise [ValidationError] if the value doesn't meet the specified constraints
      # @raise [ArgumentError] if no known numeric validator options are provided
      #
      # @example Range validation
      #   Validators::Numeric.call(5, numeric: { within: 1..10 })
      #   # => nil (no error raised)
      #
      # @example Range exclusion
      #   Validators::Numeric.call(5, numeric: { not_within: 1..10 })
      #   # raises ValidationError: "must not be within 1 and 10"
      #
      # @example Min/max validation
      #   Validators::Numeric.call(15, numeric: { min: 10, max: 20 })
      #   # => nil (no error raised)
      #
      # @example Minimum value validation
      #   Validators::Numeric.call(5, numeric: { min: 10 })
      #   # raises ValidationError: "must be at least 10"
      #
      # @example Exact value validation
      #   Validators::Numeric.call(42, numeric: { is: 42 })
      #   # => nil (no error raised)
      #
      # @example Custom error message
      #   Validators::Numeric.call(5, numeric: { min: 10, message: "Age must be at least %{min}" })
      #   # raises ValidationError: "Age must be at least 10"
      def call(value, options = {})
        case options
        in { within: within }
          raise_within_validation_error!(within.begin, within.end, options) unless within.cover?(value)
        in { not_within: not_within }
          raise_not_within_validation_error!(not_within.begin, not_within.end, options) if not_within.cover?(value)
        in { in: yn }
          raise_within_validation_error!(yn.begin, yn.end, options) unless yn.cover?(value)
        in { not_in: not_in }
          raise_not_within_validation_error!(not_in.begin, not_in.end, options) if not_in.cover?(value)
        in { min: min, max: max }
          raise_within_validation_error!(min, max, options) unless value.between?(min, max)
        in { min: min }
          raise_min_validation_error!(min, options) unless min <= value
        in { max: max }
          raise_max_validation_error!(max, options) unless value <= max
        in { is: is }
          raise_is_validation_error!(is, options) unless value == is
        in { is_not: is_not }
          raise_is_not_validation_error!(is_not, options) if value == is_not
        else
          raise ArgumentError, "no known numeric validator options given"
        end
      end

      private

      # Raises a validation error for within/range validation.
      #
      # @param min [Numeric] the minimum value of the range
      # @param max [Numeric] the maximum value of the range
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
        message = options[:within_message] || options[:in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.within",
          min:,
          max:,
          default: "must be within #{min} and #{max}"
        )
      end

      # Raises a validation error for not_within/range exclusion validation.
      #
      # @param min [Numeric] the minimum value of the excluded range
      # @param max [Numeric] the maximum value of the excluded range
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_not_within_validation_error!(1, 10, {})
      #   # raises ValidationError: "must not be within 1 and 10"
      def raise_not_within_validation_error!(min, max, options)
        message = options[:not_within_message] || options[:not_in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.not_within",
          min:,
          max:,
          default: "must not be within #{min} and #{max}"
        )
      end

      # Raises a validation error for minimum value validation.
      #
      # @param min [Numeric] the minimum allowed value
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_min_validation_error!(10, {})
      #   # raises ValidationError: "must be at least 10"
      def raise_min_validation_error!(min, options)
        message = options[:min_message] || options[:message]
        message %= { min: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.min",
          min:,
          default: "must be at least #{min}"
        )
      end

      # Raises a validation error for maximum value validation.
      #
      # @param max [Numeric] the maximum allowed value
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_max_validation_error!(100, {})
      #   # raises ValidationError: "must be at most 100"
      def raise_max_validation_error!(max, options)
        message = options[:max_message] || options[:message]
        message %= { max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.max",
          max:,
          default: "must be at most #{max}"
        )
      end

      # Raises a validation error for exact value validation.
      #
      # @param is [Numeric] the exact value required
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_is_validation_error!(42, {})
      #   # raises ValidationError: "must be 42"
      def raise_is_validation_error!(is, options)
        message = options[:is_message] || options[:message]
        message %= { is: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.is",
          is:,
          default: "must be #{is}"
        )
      end

      # Raises a validation error for exact value exclusion validation.
      #
      # @param is_not [Numeric] the exact value that is not allowed
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_is_not_validation_error!(0, {})
      #   # raises ValidationError: "must not be 0"
      def raise_is_not_validation_error!(is_not, options)
        message = options[:is_not_message] || options[:message]
        message %= { is_not: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.is_not",
          is_not:,
          default: "must not be #{is_not}"
        )
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Validators
    # Validator class for validating the length of values.
    #
    # This validator ensures that a value's length meets specified criteria.
    # It supports various length validation options including exact length,
    # minimum/maximum bounds, range validation, and exclusion patterns.
    class Length < Validator

      # Validates that the given value's length meets the specified criteria.
      #
      # @param value [Object] the value to validate (must respond to #length)
      # @param options [Hash] validation options containing length configuration
      # @option options [Hash] :length length validation configuration
      # @option options [Range] :length.within acceptable length range
      # @option options [Range] :length.not_within unacceptable length range
      # @option options [Range] :length.in alias for :within
      # @option options [Range] :length.not_in alias for :not_within
      # @option options [Integer] :length.min minimum acceptable length
      # @option options [Integer] :length.max maximum acceptable length
      # @option options [Integer] :length.is exact required length
      # @option options [Integer] :length.is_not exact forbidden length
      # @option options [String] :length.message custom error message
      # @option options [String] :length.within_message custom error message for within validation
      # @option options [String] :length.not_within_message custom error message for not_within validation
      # @option options [String] :length.in_message alias for :within_message
      # @option options [String] :length.not_in_message alias for :not_within_message
      # @option options [String] :length.min_message custom error message for minimum validation
      # @option options [String] :length.max_message custom error message for maximum validation
      # @option options [String] :length.is_message custom error message for exact validation
      # @option options [String] :length.is_not_message custom error message for exact exclusion validation
      #
      # @return [void]
      #
      # @raise [ValidationError] if the value's length doesn't meet the criteria
      # @raise [ArgumentError] if no known length validator options are provided
      #
      # @example Validating within a range
      #   Validators::Length.call("hello", length: { within: 1..10 })
      #   # => nil (no error raised)
      #
      # @example Validating minimum length
      #   Validators::Length.call("hi", length: { min: 5 })
      #   # raises ValidationError: "length must be at least 5"
      #
      # @example Validating exact length
      #   Validators::Length.call("test", length: { is: 4 })
      #   # => nil (no error raised)
      #
      # @example Validating with custom message
      #   Validators::Length.call("", length: { min: 1, message: "cannot be empty" })
      #   # raises ValidationError: "cannot be empty"
      def call(value, options = {})
        case options
        in { within: within }
          raise_within_validation_error!(within.begin, within.end, options) unless within.cover?(value.length)
        in { not_within: not_within }
          raise_not_within_validation_error!(not_within.begin, not_within.end, options) if not_within.cover?(value.length)
        in { in: yn }
          raise_within_validation_error!(yn.begin, yn.end, options) unless yn.cover?(value.length)
        in { not_in: not_in }
          raise_not_within_validation_error!(not_in.begin, not_in.end, options) if not_in.cover?(value.length)
        in { min: min, max: max }
          raise_within_validation_error!(min, max, options) unless value.length.between?(min, max)
        in { min: min }
          raise_min_validation_error!(min, options) unless min <= value.length
        in { max: max }
          raise_max_validation_error!(max, options) unless value.length <= max
        in { is: is }
          raise_is_validation_error!(is, options) unless value.length == is
        in { is_not: is_not }
          raise_is_not_validation_error!(is_not, options) if value.length == is_not
        else
          raise ArgumentError, "no known length validator options given"
        end
      end

      private

      # Raises a validation error for within/in range validation.
      #
      # @param min [Integer] the minimum acceptable length
      # @param max [Integer] the maximum acceptable length
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_within_validation_error!(5, 10, {})
      #   # raises ValidationError: "length must be within 5 and 10"
      def raise_within_validation_error!(min, max, options)
        message = options[:within_message] || options[:in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.within",
          min:,
          max:,
          default: "length must be within #{min} and #{max}"
        )
      end

      # Raises a validation error for not_within/not_in range validation.
      #
      # @param min [Integer] the minimum forbidden length
      # @param max [Integer] the maximum forbidden length
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_not_within_validation_error!(5, 10, {})
      #   # raises ValidationError: "length must not be within 5 and 10"
      def raise_not_within_validation_error!(min, max, options)
        message = options[:not_within_message] || options[:not_in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.not_within",
          min:,
          max:,
          default: "length must not be within #{min} and #{max}"
        )
      end

      # Raises a validation error for minimum length validation.
      #
      # @param min [Integer] the minimum acceptable length
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_min_validation_error!(5, {})
      #   # raises ValidationError: "length must be at least 5"
      def raise_min_validation_error!(min, options)
        message = options[:min_message] || options[:message]
        message %= { min: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.min",
          min:,
          default: "length must be at least #{min}"
        )
      end

      # Raises a validation error for maximum length validation.
      #
      # @param max [Integer] the maximum acceptable length
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_max_validation_error!(10, {})
      #   # raises ValidationError: "length must be at most 10"
      def raise_max_validation_error!(max, options)
        message = options[:max_message] || options[:message]
        message %= { max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.max",
          max:,
          default: "length must be at most #{max}"
        )
      end

      # Raises a validation error for exact length validation.
      #
      # @param is [Integer] the exact required length
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_is_validation_error!(5, {})
      #   # raises ValidationError: "length must be 5"
      def raise_is_validation_error!(is, options)
        message = options[:is_message] || options[:message]
        message %= { is: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.is",
          is:,
          default: "length must be #{is}"
        )
      end

      # Raises a validation error for exact length exclusion validation.
      #
      # @param is_not [Integer] the exact forbidden length
      # @param options [Hash] validation options
      #
      # @return [void]
      #
      # @raise [ValidationError] always raised with appropriate message
      #
      # @example
      #   raise_is_not_validation_error!(5, {})
      #   # raises ValidationError: "length must not be 5"
      def raise_is_not_validation_error!(is_not, options)
        message = options[:is_not_message] || options[:message]
        message %= { is_not: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.is_not",
          is_not:,
          default: "length must not be #{is_not}"
        )
      end

    end
  end
end

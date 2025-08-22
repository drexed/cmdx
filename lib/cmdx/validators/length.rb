# frozen_string_literal: true

module CMDx
  module Validators
    # Validates the length of a value against various constraints.
    #
    # This validator supports multiple length validation strategies including exact length,
    # minimum/maximum bounds, and range-based validation. It can be used to ensure
    # values meet specific length requirements for strings, arrays, and other
    # enumerable objects.
    module Length

      extend self

      # Validates a value's length against specified constraints.
      #
      # @param value [String, Array, Hash, Object] The value to validate (must respond to #length)
      # @param options [Hash] Validation options
      # @option options [Range] :within Range that the length must fall within (inclusive)
      # @option options [Range] :not_within Range that the length must not fall within
      # @option options [Range] :in Alias for :within
      # @option options [Range] :not_in Range that the length must not fall within
      # @option options [Integer] :min Minimum allowed length
      # @option options [Integer] :max Maximum allowed length
      # @option options [Integer] :is Exact required length
      # @option options [Integer] :is_not Length that is not allowed
      # @option options [String] :message Custom error message for all validations
      # @option options [String] :within_message Custom message for within/range validations
      # @option options [String] :in_message Custom message for :in validation
      # @option options [String] :not_within_message Custom message for not_within validation
      # @option options [String] :not_in_message Custom message for not_in validation
      # @option options [String] :min_message Custom message for minimum length validation
      # @option options [String] :max_message Custom message for maximum length validation
      # @option options [String] :is_message Custom message for exact length validation
      # @option options [String] :is_not_message Custom message for is_not validation
      #
      # @return [nil] Returns nil if validation passes
      #
      # @raise [ValidationError] When validation fails
      # @raise [ArgumentError] When unknown validation options are provided
      #
      # @example Exact length validation
      #   Length.call("hello", is: 5)
      #   # => nil (validation passes)
      # @example Range-based validation
      #   Length.call("test", within: 3..6)
      #   # => nil (validation passes - length 4 is within range)
      # @example Min/max validation
      #   Length.call("username", min: 3, max: 20)
      #   # => nil (validation passes - length 8 is between 3 and 20)
      # @example Exclusion validation
      #   Length.call("short", not_in: 1..3)
      #   # => nil (validation passes - length 5 is not in excluded range)
      def call(value, options = {})
        length = value&.length

        case options
        in within:
          raise_within_validation_error!(within.begin, within.end, options) unless within&.cover?(length)
        in not_within:
          raise_not_within_validation_error!(not_within.begin, not_within.end, options) if not_within&.cover?(length)
        in in: xin
          raise_within_validation_error!(xin.begin, xin.end, options) unless xin&.cover?(length)
        in not_in:
          raise_not_within_validation_error!(not_in.begin, not_in.end, options) if not_in&.cover?(length)
        in min:, max:
          raise_within_validation_error!(min, max, options) unless length&.between?(min, max)
        in min:
          raise_min_validation_error!(min, options) unless !length.nil? && (min <= length)
        in max:
          raise_max_validation_error!(max, options) unless !length.nil? && (length <= max)
        in is:
          raise_is_validation_error!(is, options) unless !length.nil? && (length == is)
        in is_not:
          raise_is_not_validation_error!(is_not, options) if !length.nil? && (length == is_not)
        else
          raise ArgumentError, "unknown length validator options given"
        end
      end

      private

      # Raises validation error for within/range validations.
      #
      # @param min [Integer] Minimum length value
      # @param max [Integer] Maximum length value
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] Always raised with appropriate message
      def raise_within_validation_error!(min, max, options)
        message = options[:within_message] || options[:in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.length.within", min:, max:)
      end

      # Raises validation error for not_within validations.
      #
      # @param min [Integer] Minimum length value
      # @param max [Integer] Maximum length value
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] Always raised with appropriate message
      def raise_not_within_validation_error!(min, max, options)
        message = options[:not_within_message] || options[:not_in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.length.not_within", min:, max:)
      end

      # Raises validation error for minimum length validation.
      #
      # @param min [Integer] Minimum required length
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] Always raised with appropriate message
      def raise_min_validation_error!(min, options)
        message = options[:min_message] || options[:message]
        message %= { min: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.length.min", min:)
      end

      # Raises validation error for maximum length validation.
      #
      # @param max [Integer] Maximum allowed length
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] Always raised with appropriate message
      def raise_max_validation_error!(max, options)
        message = options[:max_message] || options[:message]
        message %= { max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.length.max", max:)
      end

      # Raises validation error for exact length validation.
      #
      # @param is [Integer] Required exact length
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] Always raised with appropriate message
      def raise_is_validation_error!(is, options)
        message = options[:is_message] || options[:message]
        message %= { is: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.length.is", is:)
      end

      # Raises validation error for is_not length validation.
      #
      # @param is_not [Integer] Length that is not allowed
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] Always raised with appropriate message
      def raise_is_not_validation_error!(is_not, options)
        message = options[:is_not_message] || options[:message]
        message %= { is_not: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.length.is_not", is_not:)
      end

    end
  end
end

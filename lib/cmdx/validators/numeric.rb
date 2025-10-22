# frozen_string_literal: true

module CMDx
  module Validators
    # Validates numeric values against various constraints and ranges
    #
    # This validator ensures that numeric values meet specified criteria such as
    # minimum/maximum bounds, exact matches, or range inclusions. It supports
    # both inclusive and exclusive range validations with customizable error messages.
    module Numeric

      extend self

      # Validates a numeric value against the specified options
      #
      # @param value [Numeric] The numeric value to validate
      # @param options [Hash] Validation configuration options
      # @option options [Range] :within Range that the value must fall within (inclusive)
      # @option options [Range] :not_within Range that the value must not fall within
      # @option options [Range] :in Alias for :within option
      # @option options [Range] :not_in Alias for :not_within option
      # @option options [Numeric] :min Minimum allowed value (inclusive)
      # @option options [Numeric] :max Maximum allowed value (inclusive)
      # @option options [Numeric] :is Exact value that must match
      # @option options [Numeric] :is_not Value that must not match
      # @option options [String] :message Custom error message template
      # @option options [String] :within_message Custom message for range validations
      # @option options [String] :not_within_message Custom message for exclusion validations
      # @option options [String] :min_message Custom message for minimum validation
      # @option options [String] :max_message Custom message for maximum validation
      # @option options [String] :is_message Custom message for exact match validation
      # @option options [String] :is_not_message Custom message for exclusion validation
      #
      # @return [nil] Returns nil if validation passes
      #
      # @raise [ValidationError] When the value fails validation
      # @raise [ArgumentError] When unknown validator options are provided
      #
      # @example Validate value within a range
      #   Numeric.call(5, within: 1..10)
      #   # => nil (validation passes)
      # @example Validate minimum and maximum bounds
      #   Numeric.call(15, min: 10, max: 20)
      #   # => nil (validation passes)
      # @example Validate exact value match
      #   Numeric.call(42, is: 42)
      #   # => nil (validation passes)
      # @example Validate value exclusion
      #   Numeric.call(5, not_in: 1..10)
      #   # => nil (validation passes - 5 is not in 1..10)
      #
      # @rbs (Numeric value, Hash[Symbol, untyped] options) -> nil
      def call(value, options = {})
        case options
        in within:
          raise_within_validation_error!(within.begin, within.end, options) unless within&.cover?(value)
        in not_within:
          raise_not_within_validation_error!(not_within.begin, not_within.end, options) if not_within&.cover?(value)
        in in: xin
          raise_within_validation_error!(xin.begin, xin.end, options) unless xin&.cover?(value)
        in not_in:
          raise_not_within_validation_error!(not_in.begin, not_in.end, options) if not_in&.cover?(value)
        in min:, max:
          raise_within_validation_error!(min, max, options) unless value&.between?(min, max)
        in min:
          raise_min_validation_error!(min, options) unless !value.nil? && (min <= value)
        in max:
          raise_max_validation_error!(max, options) unless !value.nil? && (value <= max)
        in is:
          raise_is_validation_error!(is, options) unless !value.nil? && (value == is)
        in is_not:
          raise_is_not_validation_error!(is_not, options) if !value.nil? && (value == is_not)
        else
          raise ArgumentError, "unknown numeric validator options given"
        end
      end

      private

      # Raises validation error for range inclusion validation
      #
      # @param min [Numeric] The minimum value of the allowed range
      # @param max [Numeric] The maximum value of the allowed range
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      #
      # @rbs (Numeric min, Numeric max, Hash[Symbol, untyped] options) -> void
      def raise_within_validation_error!(min, max, options)
        message = options[:within_message] || options[:in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.numeric.within", min:, max:)
      end

      # Raises validation error for range exclusion validation
      #
      # @param min [Numeric] The minimum value of the excluded range
      # @param max [Numeric] The maximum value of the excluded range
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      #
      # @rbs (Numeric min, Numeric max, Hash[Symbol, untyped] options) -> void
      def raise_not_within_validation_error!(min, max, options)
        message = options[:not_within_message] || options[:not_in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.numeric.not_within", min:, max:)
      end

      # Raises validation error for minimum value validation
      #
      # @param min [Numeric] The minimum allowed value
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      #
      # @rbs (Numeric min, Hash[Symbol, untyped] options) -> void
      def raise_min_validation_error!(min, options)
        message = options[:min_message] || options[:message]
        message %= { min: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.numeric.min", min:)
      end

      # Raises validation error for maximum value validation
      #
      # @param max [Numeric] The maximum allowed value
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      #
      # @rbs (Numeric max, Hash[Symbol, untyped] options) -> void
      def raise_max_validation_error!(max, options)
        message = options[:max_message] || options[:message]
        message %= { max: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.numeric.max", max:)
      end

      # Raises validation error for exact value match validation
      #
      # @param is [Numeric] The exact value that was expected
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      #
      # @rbs (Numeric is, Hash[Symbol, untyped] options) -> void
      def raise_is_validation_error!(is, options)
        message = options[:is_message] || options[:message]
        message %= { is: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.numeric.is", is:)
      end

      # Raises validation error for value exclusion validation
      #
      # @param is_not [Numeric] The value that was not allowed
      # @param options [Hash] Validation options containing custom messages
      #
      # @raise [ValidationError] With appropriate error message
      #
      # @rbs (Numeric is_not, Hash[Symbol, untyped] options) -> void
      def raise_is_not_validation_error!(is_not, options)
        message = options[:is_not_message] || options[:message]
        message %= { is_not: } unless message.nil?

        raise ValidationError, message || Locale.t("cmdx.validators.numeric.is_not", is_not:)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Validators
    # Length validator for parameter validation based on size constraints.
    #
    # The Length validator validates the length/size of parameter values such as
    # strings, arrays, and other objects that respond to #length. It supports
    # various constraint types including ranges, boundaries, and exact lengths.
    #
    # @example Range-based length validation
    #   class ProcessUserTask < CMDx::Task
    #     required :username, length: { within: 3..20 }
    #     required :password, length: { in: 8..128 }
    #     required :bio, length: { not_within: 500..1000 }  # Avoid medium length
    #   end
    #
    # @example Boundary length validation
    #   class ProcessContentTask < CMDx::Task
    #     required :title, length: { min: 5 }
    #     required :description, length: { max: 500 }
    #     required :slug, length: { min: 3, max: 50 }  # Combined min/max
    #   end
    #
    # @example Exact length validation
    #   class ProcessCodeTask < CMDx::Task
    #     required :country_code, length: { is: 2 }  # ISO country codes
    #     required :postal_code, length: { is_not: 4 }  # Avoid 4-digit codes
    #   end
    #
    # @example Custom error messages
    #   class ProcessUserTask < CMDx::Task
    #     required :username, length: {
    #       within: 3..20,
    #       within_message: "must be between %{min} and %{max} characters"
    #     }
    #     required :password, length: {
    #       min: 8,
    #       min_message: "must be at least %{min} characters for security"
    #     }
    #   end
    #
    # @example Length validation behavior
    #   # String length validation
    #   Length.call("hello", length: { min: 3 })      # passes (length: 5)
    #   Length.call("hi", length: { min: 3 })         # raises ValidationError
    #
    #   # Array length validation
    #   Length.call([1, 2, 3], length: { is: 3 })     # passes
    #   Length.call([1, 2], length: { is: 3 })        # raises ValidationError
    #
    # @see CMDx::Validators::Numeric For numeric value validation
    # @see CMDx::Parameter Parameter validation integration
    # @see CMDx::ValidationError Raised when validation fails
    module Length

      extend self

      # Validates that a parameter value meets the specified length constraints.
      #
      # Validates the length of the value using the specified constraint type.
      # Only one constraint option can be used at a time, except for :min and :max
      # which can be combined together.
      #
      # @param value [#length] The parameter value to validate (must respond to #length)
      # @param options [Hash] Validation configuration options
      # @option options [Hash] :length Length validation configuration
      # @option options [Range] :length.within Allowed length range
      # @option options [Range] :length.not_within Forbidden length range
      # @option options [Range] :length.in Alias for :within
      # @option options [Range] :length.not_in Alias for :not_within
      # @option options [Integer] :length.min Minimum allowed length
      # @option options [Integer] :length.max Maximum allowed length
      # @option options [Integer] :length.is Exact required length
      # @option options [Integer] :length.is_not Forbidden exact length
      # @option options [String] :length.*_message Custom error messages for each constraint
      #
      # @return [void]
      # @raise [ValidationError] If value doesn't meet the length constraints
      # @raise [ArgumentError] If no valid length constraint options are provided
      #
      # @example Range validation
      #   Length.call("hello", length: { within: 3..10 })
      #   # => passes without error
      #
      # @example Failed range validation
      #   Length.call("hi", length: { within: 3..10 })
      #   # => raises ValidationError: "length must be within 3 and 10"
      #
      # @example Minimum length validation
      #   Length.call("password123", length: { min: 8 })
      #   # => passes without error
      #
      # @example Combined min/max validation
      #   Length.call("username", length: { min: 3, max: 20 })
      #   # => passes without error
      #
      # @example Exact length validation
      #   Length.call("US", length: { is: 2 })
      #   # => passes without error (country code)
      #
      # @example Array length validation
      #   Length.call([1, 2, 3, 4], length: { max: 5 })
      #   # => passes without error
      def call(value, options = {})
        case options[:length]
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

      # Raises validation error for range-based length violations.
      #
      # @param min [Integer] Range minimum length
      # @param max [Integer] Range maximum length
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_within_validation_error!(min, max, options)
        message = options.dig(:length, :within_message) ||
                  options.dig(:length, :in_message) ||
                  options.dig(:length, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.within",
          min:,
          max:,
          default: "length must be within #{min} and #{max}"
        )
      end

      # Raises validation error for forbidden range violations.
      #
      # @param min [Integer] Range minimum length
      # @param max [Integer] Range maximum length
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_not_within_validation_error!(min, max, options)
        message = options.dig(:length, :not_within_message) ||
                  options.dig(:length, :not_in_message) ||
                  options.dig(:length, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.not_within",
          min:,
          max:,
          default: "length must not be within #{min} and #{max}"
        )
      end

      # Raises validation error for minimum length violations.
      #
      # @param min [Integer] Minimum required length
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_min_validation_error!(min, options)
        message = options.dig(:length, :min_message) ||
                  options.dig(:length, :message)
        message %= { min: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.min",
          min:,
          default: "length must be at least #{min}"
        )
      end

      # Raises validation error for maximum length violations.
      #
      # @param max [Integer] Maximum allowed length
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_max_validation_error!(max, options)
        message = options.dig(:length, :max_message) ||
                  options.dig(:length, :message)
        message %= { max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.max",
          max:,
          default: "length must be at most #{max}"
        )
      end

      # Raises validation error for exact length violations.
      #
      # @param is [Integer] Required exact length
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_is_validation_error!(is, options)
        message = options.dig(:length, :is_message) ||
                  options.dig(:length, :message)
        message %= { is: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.is",
          is:,
          default: "length must be #{is}"
        )
      end

      # Raises validation error for forbidden exact length violations.
      #
      # @param is_not [Integer] Forbidden exact length
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_is_not_validation_error!(is_not, options)
        message = options.dig(:length, :is_not_message) ||
                  options.dig(:length, :message)
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

# frozen_string_literal: true

module CMDx
  module Validators
    # Numeric validator for parameter validation based on numeric value constraints.
    #
    # The Numeric validator validates numeric parameter values against various
    # constraints including ranges, boundaries, and exact values. It works with
    # any numeric type including integers, floats, decimals, and other numeric objects.
    #
    # @example Range-based numeric validation
    #   class ProcessOrderTask < CMDx::Task
    #     required :quantity, numeric: { within: 1..100 }
    #     required :price, numeric: { in: 0.01..999.99 }
    #     required :discount, numeric: { not_within: 90..100 }  # Avoid excessive discounts
    #   end
    #
    # @example Boundary numeric validation
    #   class ProcessUserTask < CMDx::Task
    #     required :age, numeric: { min: 18 }
    #     required :score, numeric: { max: 100 }
    #     required :rating, numeric: { min: 1, max: 5 }  # Combined min/max
    #   end
    #
    # @example Exact numeric validation
    #   class ProcessConfigTask < CMDx::Task
    #     required :version, numeric: { is: 2 }  # Specific version required
    #     required :legacy_flag, numeric: { is_not: 0 }  # Must not be zero
    #   end
    #
    # @example Custom error messages
    #   class ProcessOrderTask < CMDx::Task
    #     required :quantity, numeric: {
    #       within: 1..100,
    #       within_message: "must be between %{min} and %{max} items"
    #     }
    #     required :age, numeric: {
    #       min: 18,
    #       min_message: "must be at least %{min} years old"
    #     }
    #   end
    #
    # @example Numeric validation behavior
    #   # Integer validation
    #   Numeric.call(25, numeric: { min: 18 })         # passes
    #   Numeric.call(15, numeric: { min: 18 })         # raises ValidationError
    #
    #   # Float validation
    #   Numeric.call(99.99, numeric: { max: 100.0 })   # passes
    #   Numeric.call(101.5, numeric: { max: 100.0 })   # raises ValidationError
    #
    # @see CMDx::Validators::Length For length/size validation
    # @see CMDx::Parameter Parameter validation integration
    # @see CMDx::ValidationError Raised when validation fails
    class Numeric < Validator

      # Validates that a parameter value meets the specified numeric constraints.
      #
      # Validates the numeric value using the specified constraint type.
      # Only one constraint option can be used at a time, except for :min and :max
      # which can be combined together.
      #
      # @param value [Numeric] The parameter value to validate (must be numeric)
      # @param options [Hash] Validation configuration options
      # @option options [Hash] :numeric Numeric validation configuration
      # @option options [Range] :numeric.within Allowed value range
      # @option options [Range] :numeric.not_within Forbidden value range
      # @option options [Range] :numeric.in Alias for :within
      # @option options [Range] :numeric.not_in Alias for :not_within
      # @option options [Numeric] :numeric.min Minimum allowed value
      # @option options [Numeric] :numeric.max Maximum allowed value
      # @option options [Numeric] :numeric.is Exact required value
      # @option options [Numeric] :numeric.is_not Forbidden exact value
      # @option options [String] :numeric.*_message Custom error messages for each constraint
      #
      # @return [void]
      # @raise [ValidationError] If value doesn't meet the numeric constraints
      # @raise [ArgumentError] If no valid numeric constraint options are provided
      #
      # @example Range validation
      #   Numeric.call(50, numeric: { within: 1..100 })
      #   # => passes without error
      #
      # @example Failed range validation
      #   Numeric.call(150, numeric: { within: 1..100 })
      #   # => raises ValidationError: "must be within 1 and 100"
      #
      # @example Minimum value validation
      #   Numeric.call(25, numeric: { min: 18 })
      #   # => passes without error
      #
      # @example Combined min/max validation
      #   Numeric.call(3.5, numeric: { min: 1.0, max: 5.0 })
      #   # => passes without error
      #
      # @example Exact value validation
      #   Numeric.call(42, numeric: { is: 42 })
      #   # => passes without error
      #
      # @example Float validation
      #   Numeric.call(19.99, numeric: { max: 20.0 })
      #   # => passes without error
      def call(value, options = {})
        case options[:numeric]
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

      # Raises validation error for range-based numeric violations.
      #
      # @param min [Numeric] Range minimum value
      # @param max [Numeric] Range maximum value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_within_validation_error!(min, max, options)
        message = options.dig(:numeric, :within_message) ||
                  options.dig(:numeric, :in_message) ||
                  options.dig(:numeric, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.within",
          min:,
          max:,
          default: "must be within #{min} and #{max}"
        )
      end

      # Raises validation error for forbidden range violations.
      #
      # @param min [Numeric] Range minimum value
      # @param max [Numeric] Range maximum value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_not_within_validation_error!(min, max, options)
        message = options.dig(:numeric, :not_within_message) ||
                  options.dig(:numeric, :not_in_message) ||
                  options.dig(:numeric, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.not_within",
          min:,
          max:,
          default: "must not be within #{min} and #{max}"
        )
      end

      # Raises validation error for minimum value violations.
      #
      # @param min [Numeric] Minimum required value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_min_validation_error!(min, options)
        message = options.dig(:numeric, :min_message) ||
                  options.dig(:numeric, :message)
        message %= { min: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.min",
          min:,
          default: "must be at least #{min}"
        )
      end

      # Raises validation error for maximum value violations.
      #
      # @param max [Numeric] Maximum allowed value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_max_validation_error!(max, options)
        message = options.dig(:numeric, :max_message) ||
                  options.dig(:numeric, :message)
        message %= { max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.max",
          max:,
          default: "must be at most #{max}"
        )
      end

      # Raises validation error for exact value violations.
      #
      # @param is [Numeric] Required exact value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_is_validation_error!(is, options)
        message = options.dig(:numeric, :is_message) ||
                  options.dig(:numeric, :message)
        message %= { is: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.numeric.is",
          is:,
          default: "must be #{is}"
        )
      end

      # Raises validation error for forbidden exact value violations.
      #
      # @param is_not [Numeric] Forbidden exact value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_is_not_validation_error!(is_not, options)
        message = options.dig(:numeric, :is_not_message) ||
                  options.dig(:numeric, :message)
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

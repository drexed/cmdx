# frozen_string_literal: true

module CMDx
  module Validators
    # Inclusion validator for parameter validation against allowed values.
    #
    # The Inclusion validator ensures that parameter values ARE within a
    # specified set of allowed values. It supports both array-based inclusion
    # (specific values) and range-based inclusion (value ranges).
    #
    # @example Basic inclusion validation with array
    #   class ProcessOrderTask < CMDx::Task
    #     required :status, inclusion: { in: ['pending', 'processing', 'completed'] }
    #     required :priority, inclusion: { in: [1, 2, 3, 4, 5] }
    #   end
    #
    # @example Range-based inclusion
    #   class ProcessUserTask < CMDx::Task
    #     required :age, inclusion: { in: 18..120 }  # Valid age range
    #     required :score, inclusion: { within: 0..100 }  # Percentage score
    #   end
    #
    # @example Custom error messages
    #   class ProcessOrderTask < CMDx::Task
    #     required :status, inclusion: {
    #       in: ['pending', 'processing', 'completed'],
    #       of_message: "must be a valid order status"
    #     }
    #     required :age, inclusion: {
    #       in: 18..120,
    #       in_message: "must be between %{min} and %{max} years old"
    #     }
    #   end
    #
    # @example Boolean field validation
    #   class ProcessUserTask < CMDx::Task
    #     required :active, inclusion: { in: [true, false] }  # Proper boolean validation
    #     required :role, inclusion: { in: ['admin', 'user', 'guest'] }
    #   end
    #
    # @example Inclusion validation behavior
    #   # Array inclusion
    #   Inclusion.call("pending", inclusion: { in: ['pending', 'active'] })     # passes
    #   Inclusion.call("cancelled", inclusion: { in: ['pending', 'active'] })   # raises ValidationError
    #
    #   # Range inclusion
    #   Inclusion.call(25, inclusion: { in: 18..65 })  # passes
    #   Inclusion.call(15, inclusion: { in: 18..65 })  # raises ValidationError
    #
    # @see CMDx::Validators::Exclusion For validating values must not be in a set
    # @see CMDx::Parameter Parameter validation integration
    # @see CMDx::ValidationError Raised when validation fails
    class Inclusion < Validator

      # Validates that a parameter value is in the allowed set.
      #
      # Checks that the value is present in the specified array or range
      # of allowed values. Raises ValidationError if the value is not found
      # in the inclusion set.
      #
      # @param value [Object] The parameter value to validate
      # @param options [Hash] Validation configuration options
      # @option options [Hash] :inclusion Inclusion validation configuration
      # @option options [Array, Range] :inclusion.in Values/range to include
      # @option options [Array, Range] :inclusion.within Alias for :in
      # @option options [String] :inclusion.of_message Error message for array inclusion
      # @option options [String] :inclusion.in_message Error message for range inclusion
      # @option options [String] :inclusion.within_message Alias for :in_message
      # @option options [String] :inclusion.message General error message override
      #
      # @return [void]
      # @raise [ValidationError] If value is not found in the inclusion set
      #
      # @example Array inclusion validation
      #   Inclusion.call("active", inclusion: { in: ['active', 'pending'] })
      #   # => passes without error
      #
      # @example Failed array inclusion
      #   Inclusion.call("cancelled", inclusion: { in: ['active', 'pending'] })
      #   # => raises ValidationError: "must be one of: \"active\", \"pending\""
      #
      # @example Range inclusion validation
      #   Inclusion.call(25, inclusion: { in: 18..65 })
      #   # => passes without error
      #
      # @example Failed range inclusion
      #   Inclusion.call(15, inclusion: { in: 18..65 })
      #   # => raises ValidationError: "must be within 18 and 65"
      #
      # @example Boolean validation
      #   Inclusion.call(true, inclusion: { in: [true, false] })
      #   # => passes without error
      #
      # @example Custom error messages
      #   Inclusion.call("invalid", inclusion: {
      #     in: ['valid', 'pending'],
      #     of_message: "status must be valid or pending"
      #   })
      #   # => raises ValidationError: "status must be valid or pending"
      def call(value, options = {})
        values = options.dig(:inclusion, :in) ||
                 options.dig(:inclusion, :within)

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) unless values.cover?(value)
        elsif Array(values).none? { |v| v === value } # rubocop:disable Style/CaseEquality
          raise_of_validation_error!(values, options)
        end
      end

      private

      # Raises validation error for array-based inclusion violations.
      #
      # @param values [Array] The allowed values array
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_of_validation_error!(values, options)
        values  = values.map(&:inspect).join(", ")
        message = options.dig(:inclusion, :of_message) ||
                  options.dig(:inclusion, :message)
        message %= { values: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.inclusion.of",
          values:,
          default: "must be one of: #{values}"
        )
      end

      # Raises validation error for range-based inclusion violations.
      #
      # @param min [Object] Range minimum value
      # @param max [Object] Range maximum value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
      def raise_within_validation_error!(min, max, options)
        message = options.dig(:inclusion, :in_message) ||
                  options.dig(:inclusion, :within_message) ||
                  options.dig(:inclusion, :message)
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

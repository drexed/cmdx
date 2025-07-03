# frozen_string_literal: true

module CMDx
  module Validators
    # Exclusion validator for parameter validation against forbidden values.
    #
    # The Exclusion validator ensures that parameter values are NOT within a
    # specified set of forbidden values. It supports both array-based exclusion
    # (specific values) and range-based exclusion (value ranges).
    #
    # @example Basic exclusion validation with array
    #   class ProcessOrderTask < CMDx::Task
    #     required :status, exclusion: { in: ['cancelled', 'refunded'] }
    #     required :priority, exclusion: { in: [0, -1] }
    #   end
    #
    # @example Range-based exclusion
    #   class ProcessUserTask < CMDx::Task
    #     required :age, exclusion: { in: 0..17 }  # Must be 18 or older
    #     required :score, exclusion: { within: 90..100 }  # Cannot be in top 10%
    #   end
    #
    # @example Custom error messages
    #   class ProcessOrderTask < CMDx::Task
    #     required :status, exclusion: {
    #       in: ['cancelled', 'refunded'],
    #       of_message: "cannot be cancelled or refunded"
    #     }
    #     required :age, exclusion: {
    #       in: 0..17,
    #       in_message: "must be %{min} or older"
    #     }
    #   end
    #
    # @example Exclusion validation behavior
    #   # Array exclusion
    #   Exclusion.call("active", exclusion: { in: ['cancelled'] })     # passes
    #   Exclusion.call("cancelled", exclusion: { in: ['cancelled'] })  # raises ValidationError
    #
    #   # Range exclusion
    #   Exclusion.call(25, exclusion: { in: 0..17 })  # passes
    #   Exclusion.call(15, exclusion: { in: 0..17 })  # raises ValidationError
    #
    # @see CMDx::Validators::Inclusion For validating values must be in a set
    # @see CMDx::Parameter Parameter validation integration
    # @see CMDx::ValidationError Raised when validation fails
    module Exclusion

      extend self

      # Validates that a parameter value is not in the excluded set.
      #
      # Checks that the value is not present in the specified array or range
      # of forbidden values. Raises ValidationError if the value is found
      # in the exclusion set.
      #
      # @param value [Object] The parameter value to validate
      # @param options [Hash] Validation configuration options
      # @option options [Hash] :exclusion Exclusion validation configuration
      # @option options [Array, Range] :exclusion.in Values/range to exclude
      # @option options [Array, Range] :exclusion.within Alias for :in
      # @option options [String] :exclusion.of_message Error message for array exclusion
      # @option options [String] :exclusion.in_message Error message for range exclusion
      # @option options [String] :exclusion.within_message Alias for :in_message
      # @option options [String] :exclusion.message General error message override
      #
      # @return [void]
      # @raise [ValidationError] If value is found in the exclusion set
      #
      # @example Array exclusion validation
      #   Exclusion.call("pending", exclusion: { in: ['cancelled', 'failed'] })
      #   # => passes without error
      #
      # @example Failed array exclusion
      #   Exclusion.call("cancelled", exclusion: { in: ['cancelled', 'failed'] })
      #   # => raises ValidationError: "must not be one of: \"cancelled\", \"failed\""
      #
      # @example Range exclusion validation
      #   Exclusion.call(25, exclusion: { in: 0..17 })
      #   # => passes without error
      #
      # @example Failed range exclusion
      #   Exclusion.call(15, exclusion: { in: 0..17 })
      #   # => raises ValidationError: "must not be within 0 and 17"
      #
      # @example Custom error messages
      #   Exclusion.call("admin", exclusion: {
      #     in: ['admin', 'root'],
      #     of_message: "role is restricted"
      #   })
      #   # => raises ValidationError: "role is restricted"
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

      # Raises validation error for array-based exclusion violations.
      #
      # @param values [Array] The excluded values array
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
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

      # Raises validation error for range-based exclusion violations.
      #
      # @param min [Object] Range minimum value
      # @param max [Object] Range maximum value
      # @param options [Hash] Validation options containing error messages
      # @raise [ValidationError] With formatted error message
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

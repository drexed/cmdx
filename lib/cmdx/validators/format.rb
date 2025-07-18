# frozen_string_literal: true

module CMDx
  module Validators
    # Validator class for format validation using regular expressions.
    #
    # This validator ensures that a value matches or doesn't match specified
    # regular expression patterns. It supports both positive matching (with)
    # and negative matching (without) patterns, which can be used independently
    # or in combination.
    class Format < Validator

      # Validates that the given value matches the specified format pattern(s).
      #
      # @param value [Object] the value to validate
      # @param options [Hash] validation options containing format configuration
      # @option options [Hash] :format format validation configuration
      # @option options [Regexp] :format.with pattern the value must match
      # @option options [Regexp] :format.without pattern the value must not match
      # @option options [String] :format.message custom error message
      #
      # @return [void]
      #
      # @raise [ValidationError] if the value doesn't match the format requirements
      #
      # @example Validating with a positive pattern
      #   Validators::Format.call("user123", format: { with: /\A[a-z]+\d+\z/ })
      #   # => nil (no error raised)
      #
      # @example Validating with a negative pattern
      #   Validators::Format.call("admin", format: { without: /admin|root/ })
      #   # raises ValidationError: "is an invalid format"
      #
      # @example Validating with both patterns
      #   Validators::Format.call("user123", format: { with: /\A[a-z]+\d+\z/, without: /admin|root/ })
      #   # => nil (no error raised)
      #
      # @example Invalid format with positive pattern
      #   Validators::Format.call("123abc", format: { with: /\A[a-z]+\d+\z/ })
      #   # raises ValidationError: "is an invalid format"
      #
      # @example Using a custom message
      #   Validators::Format.call("123abc", format: { with: /\A[a-z]+\d+\z/, message: "Username must start with letters" })
      #   # raises ValidationError: "Username must start with letters"
      def call(value, options = {})
        valid = case options
                in { with: with, without: without }
                  value.match?(with) && !value.match?(without)
                in { with: with }
                  value.match?(with)
                in { without: without }
                  !value.match?(without)
                else
                  false
                end

        return if valid

        raise ValidationError, options[:message] || I18n.t(
          "cmdx.validators.format",
          default: "is an invalid format"
        )
      end

    end
  end
end

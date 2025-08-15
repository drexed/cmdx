# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value matches or doesn't match specified regex patterns.
    #
    # This validator supports both positive matching (with:) and negative matching (without:)
    # options. It can be used to ensure values conform to expected formats or exclude
    # unwanted patterns.
    module Format

      extend self

      # Validates a value against regex pattern options.
      #
      # @param value [String, nil] The value to validate
      # @param options [Hash] Validation options
      # @option options [Regexp] :with Regex pattern that the value must match
      # @option options [Regexp] :without Regex pattern that the value must not match
      # @option options [String] :message Custom error message
      #
      # @return [nil] Returns nil if validation passes
      #
      # @raise [ValidationError] When validation fails
      #
      # @example Basic format validation
      #   call("hello123", with: /\A[a-z]+\d+\z/)
      #   # => nil (validation passes)
      # @example Exclude specific patterns
      #   call("test@example.com", without: /\s/)
      #   # => nil (validation passes - no whitespace)
      # @example Combined with and without
      #   call("user123", with: /\A[a-z]+\d+\z/, without: /admin/)
      #   # => nil (validation passes - matches format, excludes 'admin')
      def call(value, options = {})
        match =
          case options
          in with:, without:
            value&.match?(with) && !value&.match?(without)
          in with:
            value&.match?(with)
          in without:
            !value&.match?(without)
          else
            false
          end

        return if match

        raise ValidationError, options[:message] || Locale.t("cmdx.validators.format")
      end

    end
  end
end

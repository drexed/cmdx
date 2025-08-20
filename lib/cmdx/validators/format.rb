# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value matches a specified format pattern
    #
    # This validator ensures that the given value conforms to a specific format
    # using regular expressions. It supports both direct regex matching and
    # conditional matching with inclusion/exclusion patterns.
    module Format

      extend self

      # Validates that a value matches the specified format pattern
      #
      # @param value [Object] The value to validate for format compliance
      # @param options [Hash, Regexp] Validation configuration options or direct regex pattern
      # @option options [Regexp] :with Required pattern that the value must match
      # @option options [Regexp] :without Pattern that the value must not match
      # @option options [String] :message Custom error message
      #
      # @return [nil] Returns nil if validation passes
      #
      # @raise [ValidationError] When the value doesn't match the required format
      #
      # @example Direct regex validation
      #   Format.call("user@example.com", /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      #   # => nil (validation passes)
      # @example Validate with required pattern
      #   Format.call("ABC123", with: /\A[A-Z]{3}\d{3}\z/)
      #   # => nil (validation passes)
      # @example Validate with exclusion pattern
      #   Format.call("hello", without: /\d/)
      #   # => nil (validation passes - no digits)
      # @example Validate with both patterns
      #   Format.call("test123", with: /\A\w+\z/, without: /\A\d+\z/)
      #   # => nil (validation passes - alphanumeric but not all digits)
      # @example Validate with custom message
      #   Format.call("invalid", with: /\A\d+\z/, message: "Must contain only digits")
      #   # => raises ValidationError with custom message
      def call(value, options = {})
        match =
          if options.is_a?(Regexp)
            value&.match?(options)
          else
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
          end

        return if match

        message = options[:message] if options.is_a?(Hash)
        raise ValidationError, message || Locale.t("cmdx.validators.format")
      end

    end
  end
end

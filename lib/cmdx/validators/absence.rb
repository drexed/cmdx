# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is absent or empty
    #
    # This validator ensures that the given value is nil, empty, or consists only of whitespace.
    # It handles different value types appropriately:
    # - Strings: checks for absence of non-whitespace characters
    # - Collections: checks for empty collections
    # - Other objects: checks for nil values
    module Absence

      extend self

      # Validates that a value is absent or empty
      #
      # @param value [Object] The value to validate for absence
      # @param options [Hash] Validation configuration options
      # @option options [String] :message Custom error message
      #
      # @return [nil] Returns nil if validation passes
      #
      # @raise [ValidationError] When the value is present, not empty, or contains non-whitespace characters
      #
      # @example Validate string absence
      #   Absence.call("")
      #   # => nil (validation passes)
      # @example Validate non-empty string
      #   Absence.call("hello")
      #   # => raises ValidationError
      # @example Validate array absence
      #   Absence.call([])
      #   # => nil (validation passes)
      # @example Validate non-empty array
      #   Absence.call([1, 2, 3])
      #   # => raises ValidationError
      # @example Validate with custom message
      #   Absence.call("hello", message: "Value must be empty")
      #   # => raises ValidationError with custom message
      #
      # @rbs (untyped value, ?Hash[Symbol, untyped] options) -> nil
      def call(value, options = {})
        match =
          if value.is_a?(String)
            /\S/.match?(value)
          elsif value.respond_to?(:empty?)
            !value.empty?
          else
            !value.nil?
          end

        return unless match

        message = options[:message] if options.is_a?(Hash)
        raise ValidationError, message || Locale.t("cmdx.validators.absence")
      end

    end
  end
end

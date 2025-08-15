# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is present and not empty
    #
    # This validator ensures that the given value exists and contains meaningful content.
    # It handles different value types appropriately:
    # - Strings: checks for non-whitespace characters
    # - Collections: checks for non-empty collections
    # - Other objects: checks for non-nil values
    module Presence

      extend self

      # Validates that a value is present and not empty
      #
      # @param value [Object] The value to validate for presence
      # @param options [Hash] Validation configuration options
      # @option options [String] :message Custom error message
      #
      # @return [nil] Returns nil if validation passes
      #
      # @raise [ValidationError] When the value is empty, nil, or contains only whitespace
      #
      # @example Validate string presence
      #   call("hello world")
      #   # => nil (validation passes)
      # @example Validate empty string
      #   call("   ")
      #   # => raises ValidationError
      # @example Validate array presence
      #   call([1, 2, 3])
      #   # => nil (validation passes)
      # @example Validate empty array
      #   call([])
      #   # => raises ValidationError
      # @example Validate with custom message
      #   call(nil, message: "Value cannot be blank")
      #   # => raises ValidationError with custom message
      def call(value, options = {})
        match =
          if value.is_a?(String)
            /\S/.match?(value)
          elsif value.respond_to?(:empty?)
            !value.empty?
          else
            !value.nil?
          end

        return if match

        message = options[:message] if options.is_a?(Hash)
        raise ValidationError, message || Locale.t("cmdx.validators.presence")
      end

    end
  end
end

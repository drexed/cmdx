# frozen_string_literal: true

module CMDx
  module Validators
    # Validator class for ensuring values are present (not empty or nil).
    #
    # This validator checks that a value is not empty, blank, or nil. For strings,
    # it validates that there are non-whitespace characters. For objects that respond
    # to empty?, it ensures they are not empty. For all other objects, it validates
    # they are not nil.
    class Presence < Validator

      # Validates that the given value is present (not empty or nil).
      #
      # @param value [Object] the value to validate
      # @param options [Hash] validation options containing presence configuration
      # @option options [Hash] :presence presence validation configuration
      # @option options [String] :presence.message custom error message
      #
      # @return [void] returns nothing when validation passes
      #
      # @raise [ValidationError] if the value is empty, blank, or nil
      #
      # @example Validating a non-empty string
      #   Validators::Presence.call("hello", presence: {})
      #   #=> nil (no error raised)
      #
      # @example Validating an empty string
      #   Validators::Presence.call("", presence: {})
      #   # raises ValidationError: "cannot be empty"
      #
      # @example Validating a whitespace-only string
      #   Validators::Presence.call("   ", presence: {})
      #   # raises ValidationError: "cannot be empty"
      #
      # @example Validating a non-empty array
      #   Validators::Presence.call([1, 2, 3], presence: {})
      #   #=> nil (no error raised)
      #
      # @example Validating an empty array
      #   Validators::Presence.call([], presence: {})
      #   # raises ValidationError: "cannot be empty"
      #
      # @example Validating a nil value
      #   Validators::Presence.call(nil, presence: {})
      #   # raises ValidationError: "cannot be empty"
      #
      # @example Using a custom message
      #   Validators::Presence.call("", presence: { message: "This field is required" })
      #   # raises ValidationError: "This field is required"
      def call(value, options = {})
        present =
          if value.is_a?(String)
            /\S/.match?(value)
          elsif value.respond_to?(:empty?)
            !value.empty?
          else
            !value.nil?
          end

        return if present

        message = options[:message] if options.is_a?(Hash)
        raise ValidationError, message || I18n.t(
          "cmdx.validators.presence",
          default: "cannot be empty"
        )
      end

    end
  end
end

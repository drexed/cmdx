# frozen_string_literal: true

module CMDx
  module Validators
    # Presence validator for parameter validation ensuring values are not empty.
    #
    # The Presence validator checks that parameter values are not nil, not empty
    # strings (including whitespace-only strings), and not empty collections.
    # It provides intelligent presence checking for different value types with
    # appropriate logic for strings, arrays, hashes, and other objects.
    #
    # @example Basic presence validation
    #   class ProcessUserTask < CMDx::Task
    #     required :name, presence: true
    #     required :email, presence: true
    #     optional :bio, presence: true  # Only validated if provided
    #   end
    #
    # @example Custom presence message
    #   class ProcessUserTask < CMDx::Task
    #     required :name, presence: { message: "is required for processing" }
    #     required :email, presence: { message: "must be provided" }
    #   end
    #
    # @example Boolean field presence validation
    #   class ProcessUserTask < CMDx::Task
    #     # For boolean fields, use inclusion instead of presence
    #     required :active, inclusion: { in: [true, false] }
    #     # presence: true would fail for false values
    #   end
    #
    # @example Presence validation behavior
    #   # String presence checking
    #   Presence.call("hello", presence: true)     # passes
    #   Presence.call("", presence: true)          # raises ValidationError
    #   Presence.call("   ", presence: true)       # raises ValidationError (whitespace only)
    #   Presence.call("\n\t", presence: true)      # raises ValidationError (whitespace only)
    #
    #   # Collection presence checking
    #   Presence.call([1, 2], presence: true)      # passes
    #   Presence.call([], presence: true)          # raises ValidationError
    #   Presence.call({a: 1}, presence: true)      # passes
    #   Presence.call({}, presence: true)          # raises ValidationError
    #
    #   # General object presence checking
    #   Presence.call(42, presence: true)          # passes
    #   Presence.call(0, presence: true)           # passes (zero is present)
    #   Presence.call(false, presence: true)       # passes (false is present)
    #   Presence.call(nil, presence: true)         # raises ValidationError
    #
    # @see CMDx::Validators::Inclusion For validating boolean fields
    # @see CMDx::Parameter Parameter validation integration
    # @see CMDx::ValidationError Raised when validation fails
    module Presence

      module_function

      # Validates that a parameter value is present (not empty or nil).
      #
      # Performs intelligent presence checking based on the value type:
      # - Strings: Must contain non-whitespace characters
      # - Collections: Must not be empty (arrays, hashes, etc.)
      # - Other objects: Must not be nil
      #
      # @param value [Object] The parameter value to validate
      # @param options [Hash] Validation configuration options
      # @option options [Boolean, Hash] :presence Presence validation configuration
      # @option options [String] :presence.message Custom error message
      #
      # @return [void]
      # @raise [ValidationError] If value is not present according to type-specific rules
      #
      # @example String presence validation
      #   Presence.call("hello", presence: true)     # passes
      #   Presence.call("", presence: true)          # raises ValidationError
      #   Presence.call("   ", presence: true)       # raises ValidationError
      #
      # @example Collection presence validation
      #   Presence.call([1, 2, 3], presence: true)   # passes
      #   Presence.call([], presence: true)          # raises ValidationError
      #   Presence.call({key: "value"}, presence: true) # passes
      #   Presence.call({}, presence: true)          # raises ValidationError
      #
      # @example Object presence validation
      #   Presence.call(42, presence: true)          # passes
      #   Presence.call(false, presence: true)       # passes (false is present)
      #   Presence.call(nil, presence: true)         # raises ValidationError
      #
      # @example Custom error message
      #   Presence.call("", presence: { message: "is required" })
      #   # => raises ValidationError: "is required"
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

        message = options.dig(:presence, :message) if options[:presence].is_a?(Hash)
        raise ValidationError, message || I18n.t(
          "cmdx.validators.presence",
          default: "cannot be empty"
        )
      end

    end
  end
end

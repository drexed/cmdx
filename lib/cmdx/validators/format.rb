# frozen_string_literal: true

module CMDx
  module Validators
    # Format validator for parameter validation using regular expressions.
    #
    # The Format validator validates parameter values against regular expression
    # patterns. It supports both positive matching (with) and negative matching
    # (without) patterns, and can combine both for complex format validation.
    #
    # @example Basic format validation with positive pattern
    #   class ProcessUserTask < CMDx::Task
    #     required :email, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
    #     required :phone, format: { with: /\A\d{3}-\d{3}-\d{4}\z/ }
    #   end
    #
    # @example Format validation with negative pattern
    #   class ProcessContentTask < CMDx::Task
    #     required :username, format: { without: /\A(admin|root|system)\z/i }
    #     required :content, format: { without: /spam|viagra/i }
    #   end
    #
    # @example Combined positive and negative patterns
    #   class ProcessUserTask < CMDx::Task
    #     required :password, format: {
    #       with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/,  # Strong password
    #       without: /password|123456/i  # Common weak patterns
    #     }
    #   end
    #
    # @example Custom error message
    #   class ProcessUserTask < CMDx::Task
    #     required :email, format: {
    #       with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i,
    #       message: "must be a valid email address"
    #     }
    #   end
    #
    # @example Format validation behavior
    #   # Positive pattern matching
    #   Format.call("user@example.com", format: { with: /@/ })     # passes
    #   Format.call("invalid-email", format: { with: /@/ })        # raises ValidationError
    #
    #   # Negative pattern matching
    #   Format.call("username", format: { without: /admin/ })      # passes
    #   Format.call("admin", format: { without: /admin/ })         # raises ValidationError
    #
    # @see CMDx::Parameter Parameter validation integration
    # @see CMDx::ValidationError Raised when validation fails
    module Format

      module_function

      # Validates that a parameter value matches the specified format patterns.
      #
      # Validates the value against the provided regular expression patterns.
      # Supports positive matching (with), negative matching (without), or both.
      # The value must match all specified conditions to pass validation.
      #
      # @param value [String] The parameter value to validate
      # @param options [Hash] Validation configuration options
      # @option options [Hash] :format Format validation configuration
      # @option options [Regexp] :format.with Pattern the value must match
      # @option options [Regexp] :format.without Pattern the value must not match
      # @option options [String] :format.message Custom error message
      #
      # @return [void]
      # @raise [ValidationError] If value doesn't match the format requirements
      #
      # @example Successful positive pattern validation
      #   Format.call("user@example.com", format: { with: /@/ })
      #   # => passes without error
      #
      # @example Failed positive pattern validation
      #   Format.call("invalid-email", format: { with: /@/ })
      #   # => raises ValidationError: "is an invalid format"
      #
      # @example Successful negative pattern validation
      #   Format.call("username", format: { without: /admin/ })
      #   # => passes without error
      #
      # @example Failed negative pattern validation
      #   Format.call("admin", format: { without: /admin/ })
      #   # => raises ValidationError: "is an invalid format"
      #
      # @example Combined pattern validation
      #   Format.call("StrongPass123", format: {
      #     with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/,
      #     without: /password/i
      #   })
      #   # => passes without error
      #
      # @example Custom error message
      #   Format.call("weak", format: {
      #     with: /\A.{8,}\z/,
      #     message: "must be at least 8 characters"
      #   })
      #   # => raises ValidationError: "must be at least 8 characters"
      def call(value, options = {})
        valid = case options[:format]
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

        raise ValidationError, options.dig(:format, :message) || I18n.t(
          "cmdx.validators.format",
          default: "is an invalid format"
        )
      end

    end
  end
end

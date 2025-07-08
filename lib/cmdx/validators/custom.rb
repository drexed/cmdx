# frozen_string_literal: true

module CMDx
  module Validators
    # Custom validator for parameter validation using user-defined validation logic.
    #
    # The Custom validator allows you to implement your own validation logic by
    # providing a callable validator class or object. This enables complex business
    # rule validation that goes beyond the built-in validators.
    #
    # @example Basic custom validator
    #   class EmailDomainValidator
    #     def self.call(value, options)
    #       allowed_domains = options.dig(:custom, :domains) || ['example.com']
    #       domain = value.split('@').last
    #       allowed_domains.include?(domain)
    #     end
    #   end
    #
    #   class ProcessUserTask < CMDx::Task
    #     required :email, custom: { validator: EmailDomainValidator }
    #   end
    #
    # @example Custom validator with options
    #   class ProcessUserTask < CMDx::Task
    #     required :email, custom: {
    #       validator: EmailDomainValidator,
    #       domains: ['company.com', 'partner.org'],
    #       message: "must be from an approved domain"
    #     }
    #   end
    #
    # @example Complex business logic validator
    #   class AgeValidator
    #     def self.call(value, options)
    #       min_age = options.dig(:custom, :min_age) || 18
    #       max_age = options.dig(:custom, :max_age) || 120
    #       value.between?(min_age, max_age)
    #     end
    #   end
    #
    # @example Proc-based validator
    #   class ProcessOrderTask < CMDx::Task
    #     required :discount, custom: {
    #       validator: ->(value, options) { value <= 50 },
    #       message: "cannot exceed 50%"
    #     }
    #   end
    #
    # @see CMDx::Parameter Parameter validation integration
    # @see CMDx::ValidationError Raised when validation fails
    class Custom < Validator

      # Validates a parameter value using a custom validator.
      #
      # Calls the provided validator with the value and options, expecting
      # a truthy return value for successful validation. If validation fails,
      # raises a ValidationError with the configured or default message.
      #
      # @param value [Object] The parameter value to validate
      # @param options [Hash] Validation configuration options
      # @option options [Hash] :custom Custom validation configuration
      # @option options [#call] :custom.validator Callable validator object/class
      # @option options [String] :custom.message Custom error message
      # @option options [Hash] :custom Additional options passed to validator
      #
      # @return [void]
      # @raise [ValidationError] If the custom validator returns falsy
      #
      # @example Successful validation
      #   validator = ->(value, options) { value.length > 5 }
      #   Custom.call("hello world", custom: { validator: validator })
      #   # => passes without error
      #
      # @example Failed validation with default message
      #   validator = ->(value, options) { value > 100 }
      #   Custom.call(50, custom: { validator: validator })
      #   # => raises ValidationError: "is not valid"
      #
      # @example Failed validation with custom message
      #   validator = ->(value, options) { value.even? }
      #   Custom.call(7, custom: { validator: validator, message: "must be even" })
      #   # => raises ValidationError: "must be even"
      #
      # @example Validator with additional options
      #   validator = ->(value, opts) { value >= opts.dig(:custom, :minimum) }
      #   Custom.call(10, custom: { validator: validator, minimum: 5 })
      #   # => passes without error
      def call(value, options = {})
        return if options.dig(:custom, :validator).call(value, options)

        raise ValidationError, options.dig(:custom, :message) || I18n.t(
          "cmdx.validators.custom",
          default: "is not valid"
        )
      end

    end
  end
end

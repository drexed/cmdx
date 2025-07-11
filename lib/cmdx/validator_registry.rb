# frozen_string_literal: true

module CMDx
  # Registry for managing validator definitions and execution within tasks.
  #
  # This registry handles the registration and execution of validators for
  # parameter validation, including built-in validators and custom validators
  # that can be registered at runtime.
  #
  # @since 1.0.0
  class ValidatorRegistry

    # The internal hash storing validator definitions.
    #
    # @return [Hash] hash containing validator type keys and validator class values
    attr_reader :registry

    # Initializes a new validator registry with built-in validators.
    #
    # @return [ValidatorRegistry] a new validator registry instance
    #
    # @example Creating a validator registry
    #   ValidatorRegistry.new
    def initialize
      @registry = {
        exclusion: Validators::Exclusion,
        format: Validators::Format,
        inclusion: Validators::Inclusion,
        length: Validators::Length,
        numeric: Validators::Numeric,
        presence: Validators::Presence
      }
    end

    # Registers a custom validator for a specific type.
    #
    # @param type [Symbol] the validator type to register
    # @param validator [Class, Module, Symbol, Proc] the validator to register
    #
    # @return [ValidatorRegistry] returns self for method chaining
    #
    # @example Registering a custom validator class
    #   registry.register(:email, EmailValidator)
    #
    # @example Registering a Proc validator
    #   registry.register(:custom, ->(value, opts) { value.length > 3 })
    #
    # @example Registering a Symbol validator
    #   registry.register(:password, :validate_password_strength)
    #
    # @example Chaining validator registrations
    #   registry.register(:phone, PhoneValidator)
    #           .register(:zipcode, ZipcodeValidator)
    def register(type, validator)
      registry[type] = validator
      self
    end

    # Executes validation for a specific type on a given value.
    #
    # @param task [Task] the task instance to execute validation on
    # @param type [Symbol] the validator type to execute
    # @param value [Object] the value to validate
    # @param options [Hash] options for conditional validation execution
    #
    # @return [Object, nil] returns the validation result or nil if skipped
    #
    # @raise [UnknownValidatorError] when the validator type is not registered
    #
    # @example Validating with a built-in validator
    #   registry.call(task, :presence, "", {})
    #
    # @example Validating with options
    #   registry.call(task, :length, "test", { minimum: 5 })
    def call(task, type, value, options = {})
      raise UnknownValidatorError, "unknown validator #{type}" unless registry.key?(type)
      return unless task.cmdx_eval(options)

      case validator = registry[type]
      when Symbol, String, Proc
        task.cmdx_try(validator, value, options)
      else
        validator.call(value, options)
      end
    end

  end
end

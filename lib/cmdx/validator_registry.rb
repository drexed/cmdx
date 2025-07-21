# frozen_string_literal: true

module CMDx
  # Registry for parameter validation handlers in the CMDx framework.
  #
  # ValidatorRegistry manages the collection of validator implementations
  # that can be used for parameter validation in tasks. It provides a
  # centralized registry where validators can be registered by type and
  # invoked during parameter processing. The registry comes pre-loaded
  # with built-in validators for common validation scenarios.
  class ValidatorRegistry

    # @return [Hash] internal hash storing validator implementations by type
    attr_reader :registry

    # Creates a new validator registry with built-in validators.
    #
    # The registry is initialized with standard validators including
    # exclusion, format, inclusion, length, numeric, and presence validation.
    # These built-in validators provide common validation functionality
    # that can be immediately used without additional registration.
    #
    # @return [ValidatorRegistry] a new registry instance with built-in validators
    #
    # @example Create a new validator registry
    #   registry = ValidatorRegistry.new
    #   registry.registry.keys #=> [:exclusion, :format, :inclusion, :length, :numeric, :presence]
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

    # Registers a new validator implementation for the specified type.
    #
    # This method allows custom validators to be added to the registry,
    # enabling extended validation functionality beyond the built-in
    # validators. The validator can be a class, symbol, string, or proc
    # that implements the validation logic.
    #
    # @param type [Symbol] the validator type identifier
    # @param validator [Class, Symbol, String, Proc] the validator implementation
    #
    # @return [ValidatorRegistry] returns self for method chaining
    #
    # @example Register a custom validator class
    #   registry.register(:email, EmailValidator)
    #
    # @example Register a symbol validator
    #   registry.register(:zipcode, :validate_zipcode)
    #
    # @example Register a proc validator
    #   registry.register(:positive, ->(value, options) { value > 0 })
    #
    # @example Method chaining
    #   registry.register(:email, EmailValidator)
    #           .register(:phone, PhoneValidator)
    def register(type, validator)
      registry[type] = validator
      self
    end

    # Executes validation for a parameter value using the specified validator type.
    #
    # This method performs validation by looking up the registered validator
    # for the given type and executing it with the provided value and options.
    # The validation is only performed if the task's evaluation of the options
    # returns a truthy value, allowing for conditional validation.
    #
    # @param task [Task] the task instance performing validation
    # @param type [Symbol] the validator type to use
    # @param value [Object] the value to validate
    # @param options [Hash] validation options and configuration
    #
    # @return [Object, nil] the validation result or nil if validation was skipped
    #
    # @raise [UnknownValidatorError] if the specified validator type is not registered
    #
    # @example Validate with a built-in validator
    #   registry.call(task, :presence, "", {})
    #   #=> may raise ValidationError if value is blank
    #
    # @example Validate with options
    #   registry.call(task, :length, "hello", minimum: 3, maximum: 10)
    #   #=> validates string length is between 3 and 10 characters
    #
    # @example Conditional validation that gets skipped
    #   registry.call(task, :presence, "", if: -> { false })
    #   #=> returns nil without performing validation
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

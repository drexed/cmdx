# frozen_string_literal: true

module CMDx
  ##
  # ValidatorRegistry manages the collection of parameter validators available within
  # CMDx tasks. It provides both built-in validators for common validation patterns and
  # the ability to register custom validators for specialized validation needs.
  #
  # The registry combines default validators with custom registrations, allowing
  # tasks to leverage both standard validation patterns and domain-specific validation logic.
  # Custom validators can be classes, callable objects, or method symbols that reference
  # validation methods on the task instance.
  #
  # @example Basic usage with built-in validators
  #   registry = ValidatorRegistry.new
  #   registry.call(:presence, "hello", presence: true)  # validates presence
  #   registry.call(:numeric, 42, numeric: { min: 0 })  # validates numeric constraints
  #   registry.call(:format, "user@example.com", format: { with: /@/ })  # validates format
  #
  # @example Registering custom validators
  #   registry = ValidatorRegistry.new
  #   registry.register(:email, EmailValidator.new)
  #   registry.register(:phone, proc { |value, options| PhoneValidator.validate(value) })
  #   registry.register(:custom, :validate_custom_field)  # method symbol
  #   registry.call(:email, "user@example.com", email: { domain: "example.com" })
  #
  # @example Using custom validators with tasks
  #   class ProcessUserTask < CMDx::Task
  #     required :email, email: { domain: "company.com" }
  #     required :phone, phone: { country: "US" }
  #     required :custom_field, custom: true
  #
  #     private
  #
  #     def validate_custom_field(value, options)
  #       # Custom validation logic here
  #       raise CMDx::ValidationError, "invalid custom field" unless value.valid?
  #     end
  #   end
  #
  # @see Parameter Parameter validation integration
  # @see Task Task validation system
  # @since 1.1.0
  class ValidatorRegistry

    ##
    # @!attribute [r] registry
    #   @return [Hash] the complete registry of validators (default + custom)
    attr_reader :registry

    ##
    # Initializes a new ValidatorRegistry with optional custom validators.
    #
    # The registry combines any provided custom validators with the default
    # validators, with custom validators taking precedence for overlapping keys.
    #
    # @param registry [Hash] optional hash of custom validators
    # @return [ValidatorRegistry] new registry instance
    #
    # @example Initialize with defaults only
    #   registry = ValidatorRegistry.new
    #
    # @example Initialize with custom validators
    #   registry = ValidatorRegistry.new(
    #     email: EmailValidator,
    #     phone: PhoneValidator.new
    #   )
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

    ##
    # Registers a custom validator for a specific validation type.
    #
    # Custom validators can be classes that respond to `call(value, options)`,
    # callable objects like procs and lambdas, or method symbols that will be
    # called on the task instance. Registered validators override any existing
    # validator for the same type.
    #
    # @param type [Symbol] the validation type to register validator for
    # @param validator [#call, Symbol] validator class, callable object, or method symbol
    # @return [ValidatorRegistry] self for method chaining
    #
    # @example Register a validator class
    #   registry.register(:email, EmailValidator)
    #
    # @example Register a proc validator
    #   registry.register(:phone, proc { |value, options|
    #     PhoneValidator.validate(value, options)
    #   })
    #
    # @example Register a method symbol validator
    #   registry.register(:custom, :validate_custom_field)
    #
    # @example Method chaining
    #   registry.register(:email, EmailValidator)
    #           .register(:phone, PhoneValidator.new)
    #           .register(:custom, :validate_custom)
    def register(type, validator)
      registry[type] = validator
      self
    end

    ##
    # Applies validation to a value using the specified validator type.
    #
    # Looks up the validator for the given type and applies it to the value
    # with any provided options. For symbol validators, a task instance must
    # be provided to resolve the method. Raises an error if the type is not registered.
    #
    # @param type [Symbol] the validator type to apply
    # @param value [Object] the value to validate
    # @param options [Hash] optional parameters for the validator
    # @param task [Task, nil] task instance for symbol validator resolution
    # @return [void]
    # @raise [UnknownValidatorError] if the type is not registered
    # @raise [ArgumentError] if a symbol validator is used without a task
    #
    # @example Apply built-in validator
    #   registry.call(:presence, "hello", presence: true)
    #   registry.call(:numeric, 42, numeric: { min: 0 })
    #
    # @example Apply custom validator
    #   registry.register(:email, EmailValidator.new)
    #   registry.call(:email, "user@example.com", email: { domain: "example.com" })
    #
    # @example Apply symbol validator
    #   registry.register(:custom, :validate_custom_field)
    #   registry.call(:custom, "value", { custom: true }, task)
    #
    # @example Apply validator with options
    #   registry.call(:format, "user@example.com", format: { with: /@/ })
    def call(task, type, value, options = {})
      raise UnknownValidatorError, "unknown validator #{type}" unless registry.key?(type)

      validator = registry[type]

      if validator.is_a?(Symbol) || validator.is_a?(String)
        task.__cmdx_try(validator, value, options)
      else
        validator.call(value, options)
      end
    end

  end
end

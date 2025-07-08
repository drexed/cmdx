# frozen_string_literal: true

module CMDx
  ##
  # ValidatorRegistry manages the collection of parameter validators available within
  # CMDx tasks. It provides both built-in validators for common validation patterns and
  # the ability to register custom validators for specialized validation needs.
  #
  # The registry combines default validators with custom registrations, allowing
  # tasks to leverage both standard validation patterns and domain-specific validation logic.
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
  #   registry.call(:email, "user@example.com", email: { domain: "example.com" })
  #
  # @example Using custom validators with tasks
  #   class ProcessUserTask < CMDx::Task
  #     required :email, email: { domain: "company.com" }
  #     required :phone, phone: { country: "US" }
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
    #     email: EmailValidator.new,
    #     phone: PhoneValidator.new
    #   )
    def initialize
      @registry = {
        custom: Validators::Custom,
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
    # Custom validators can be classes that respond to `call(value, options)`
    # or callable objects like procs and lambdas. Registered validators
    # override any existing validator for the same type.
    #
    # @param type [Symbol] the validation type to register validator for
    # @param validator [#call] validator class or callable object
    # @return [ValidatorRegistry] self for method chaining
    #
    # @example Register a validator class
    #   registry.register(:email, EmailValidator.new)
    #
    # @example Register a proc validator
    #   registry.register(:phone, proc { |value, options|
    #     PhoneValidator.validate(value, options)
    #   })
    #
    # @example Method chaining
    #   registry.register(:email, EmailValidator.new)
    #           .register(:phone, PhoneValidator.new)
    def register(type, validator)
      registry[type] = validator
      self
    end

    ##
    # Applies validation to a value using the specified validator type.
    #
    # Looks up the validator for the given type and applies it to the value
    # with any provided options. Raises an error if the type is not registered.
    #
    # @param type [Symbol] the validator type to apply
    # @param value [Object] the value to validate
    # @param options [Hash] optional parameters for the validator
    # @return [void]
    # @raise [UnknownValidatorError] if the type is not registered
    #
    # @example Apply built-in validator
    #   registry.call(:presence, "hello", presence: true)
    #   registry.call(:numeric, 42, numeric: { min: 0 })
    #
    # @example Apply custom validator
    #   registry.register(:email, EmailValidator.new)
    #   registry.call(:email, "user@example.com", email: { domain: "example.com" })
    #
    # @example Apply validator with options
    #   registry.call(:format, "user@example.com", format: { with: /@/ })
    def call(type, value, options = {})
      raise UnknownValidatorError, "unknown validator #{type}" unless registry.key?(type)

      validator = registry[type]
      validator.call(value, options)
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Registry for managing validation rules and their corresponding validator classes.
  # Provides methods to register, deregister, and execute validators against task values.
  class ValidatorRegistry

    extend Forwardable

    attr_reader :registry
    alias to_h registry

    def_delegators :registry, :keys

    # Initialize a new validator registry with default validators.
    #
    # @param registry [Hash, nil] Optional hash mapping validator names to validator classes
    #
    # @return [ValidatorRegistry] A new validator registry instance
    def initialize(registry = nil)
      @registry = registry || {
        exclusion: Validators::Exclusion,
        format: Validators::Format,
        inclusion: Validators::Inclusion,
        length: Validators::Length,
        numeric: Validators::Numeric,
        presence: Validators::Presence
      }
    end

    # Create a duplicate of the registry with copied internal state.
    #
    # @return [ValidatorRegistry] A new validator registry with duplicated registry hash
    def dup
      self.class.new(registry.dup)
    end

    # Register a new validator class with the given name.
    #
    # @param name [String, Symbol] The name to register the validator under
    # @param validator [Class] The validator class to register
    #
    # @return [ValidatorRegistry] Returns self for method chaining
    #
    # @example
    #   registry.register(:custom, CustomValidator)
    #   registry.register("email", EmailValidator)
    def register(name, validator)
      registry[name.to_sym] = validator
      self
    end

    # Remove a validator from the registry by name.
    #
    # @param name [String, Symbol] The name of the validator to remove
    #
    # @return [ValidatorRegistry] Returns self for method chaining
    #
    # @example
    #   registry.deregister(:format)
    #   registry.deregister("presence")
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # Validate a value using the specified validator type and options.
    #
    # @param type [Symbol] The type of validator to use
    # @param task [Task] The task context for validation
    # @param value [Object] The value to validate
    # @param options [Hash, Object] Validation options or condition
    # @option options [Boolean] :allow_nil Whether to allow nil values
    #
    # @return [void]
    #
    # @raise [TypeError] When the validator type is not registered
    #
    # @example
    #   registry.validate(:presence, task, user.name, presence: true)
    #   registry.validate(:length, task, password, { min: 8, allow_nil: false })
    def validate(type, task, value, options = {})
      raise TypeError, "unknown validator type #{type.inspect}" unless registry.key?(type)

      match =
        if options.is_a?(Hash)
          case options
          in allow_nil: then allow_nil && value.nil?
          else Utils::Condition.evaluate(task, options, value)
          end
        else
          options
        end

      return unless match

      Utils::Call.invoke(task, registry[type], value, options)
    end

  end
end

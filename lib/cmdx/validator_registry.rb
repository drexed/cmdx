# frozen_string_literal: true

module CMDx
  # Registry for managing validation rules and their corresponding validator classes.
  # Provides methods to register, deregister, and execute validators against task values.
  #
  # Supports copy-on-write semantics: a duped registry shares the parent's
  # data until a write operation triggers materialization.
  class ValidatorRegistry

    extend Forwardable

    def_delegators :registry, :keys

    # Initialize a new validator registry with default validators.
    #
    # @param registry [Hash, nil] Optional hash mapping validator names to validator classes
    #
    # @return [ValidatorRegistry] A new validator registry instance
    #
    # @rbs (?Hash[Symbol, Class]? registry) -> void
    def initialize(registry = nil)
      @registry = registry || {
        absence: Validators::Absence,
        exclusion: Validators::Exclusion,
        format: Validators::Format,
        inclusion: Validators::Inclusion,
        length: Validators::Length,
        numeric: Validators::Numeric,
        presence: Validators::Presence
      }
    end

    # Sets up copy-on-write state when duplicated via dup.
    #
    # @param source [ValidatorRegistry] The registry being duplicated
    #
    # @rbs (ValidatorRegistry source) -> void
    def initialize_dup(source)
      @parent = source
      @registry = nil
      super
    end

    # Returns the internal registry mapping validator types to classes.
    # Delegates to the parent registry when not yet materialized.
    #
    # @return [Hash{Symbol => Class}] Hash of validator type names to validator classes
    #
    # @example
    #   registry.registry # => { presence: Validators::Presence, format: Validators::Format }
    #
    # @rbs () -> Hash[Symbol, Class]
    def registry
      @registry || @parent.registry
    end
    alias to_h registry

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
    #
    # @rbs ((String | Symbol) name, Class validator) -> self
    def register(name, validator)
      materialize!

      @registry[name.to_sym] = validator
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
    #
    # @rbs ((String | Symbol) name) -> self
    def deregister(name)
      materialize!

      @registry.delete(name.to_sym)
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
    # @raise [TypeError] When the validator type is not registered
    #
    # @example
    #   registry.validate(:presence, task, user.name, presence: true)
    #   registry.validate(:length, task, password, { min: 8, allow_nil: false })
    #
    # @rbs (Symbol type, Task task, untyped value, untyped options) -> untyped
    def validate(type, task, value, options = {})
      raise TypeError, "unknown validator type #{type.inspect}" unless registry.key?(type)

      match =
        if options.is_a?(Hash)
          case options
          in allow_nil: then !(allow_nil && value.nil?)
          else Utils::Condition.evaluate(task, options, value)
          end
        else
          options
        end

      return unless match

      Utils::Call.invoke(task, registry[type], value, options)
    end

    private

    # Copies the parent's registry data into this instance,
    # severing the copy-on-write link.
    #
    # @rbs () -> void
    def materialize!
      return if @registry

      @registry = @parent.registry.dup
      @parent = nil
    end

  end
end

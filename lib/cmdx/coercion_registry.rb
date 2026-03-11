# frozen_string_literal: true

module CMDx
  # Registry for managing type coercion handlers.
  #
  # Provides a centralized way to register, deregister, and execute type coercions
  # for various data types including arrays, numbers, dates, and other primitives.
  #
  # Supports copy-on-write semantics: a duped registry shares the parent's
  # data until a write operation triggers materialization.
  class CoercionRegistry

    # Initialize a new coercion registry.
    #
    # @param registry [Hash{Symbol => Class}, nil] optional initial registry hash
    #
    # @example
    #   registry = CoercionRegistry.new
    #   registry = CoercionRegistry.new(custom: CustomCoercion)
    #
    # @rbs (?Hash[Symbol, Class]? registry) -> void
    def initialize(registry = nil)
      @registry = registry || {
        array: Coercions::Array,
        big_decimal: Coercions::BigDecimal,
        boolean: Coercions::Boolean,
        complex: Coercions::Complex,
        date: Coercions::Date,
        datetime: Coercions::DateTime,
        float: Coercions::Float,
        hash: Coercions::Hash,
        integer: Coercions::Integer,
        rational: Coercions::Rational,
        string: Coercions::String,
        time: Coercions::Time
      }
    end

    # Sets up copy-on-write state when duplicated via dup.
    #
    # @param source [CoercionRegistry] The registry being duplicated
    #
    # @rbs (CoercionRegistry source) -> void
    def initialize_dup(source)
      @parent = source
      @registry = nil
      super
    end

    # Returns the internal registry mapping coercion types to handler classes.
    # Delegates to the parent registry when not yet materialized.
    #
    # @return [Hash{Symbol => Class}] Hash of coercion type names to coercion classes
    #
    # @example
    #   registry.registry # => { integer: Coercions::Integer, boolean: Coercions::Boolean }
    #
    # @rbs () -> Hash[Symbol, Class]
    def registry
      @registry || @parent.registry
    end
    alias to_h registry

    # Register a new coercion handler for a type.
    #
    # @param name [Symbol, String] the type name to register
    # @param coercion [Class] the coercion class to handle this type
    #
    # @return [CoercionRegistry] self for method chaining
    #
    # @example
    #   registry.register(:custom_type, CustomCoercion)
    #   registry.register("another_type", AnotherCoercion)
    #
    # @rbs ((Symbol | String) name, Class coercion) -> self
    def register(name, coercion)
      materialize!

      @registry[name.to_sym] = coercion
      self
    end

    # Remove a coercion handler for a type.
    #
    # @param name [Symbol, String] the type name to deregister
    #
    # @return [CoercionRegistry] self for method chaining
    #
    # @example
    #   registry.deregister(:custom_type)
    #   registry.deregister("another_type")
    #
    # @rbs ((Symbol | String) name) -> self
    def deregister(name)
      materialize!

      @registry.delete(name.to_sym)
      self
    end

    # Coerce a value to the specified type using the registered handler.
    #
    # @param type [Symbol] the type to coerce to
    # @param task [Object] the task context for the coercion
    # @param value [Object] the value to coerce
    # @param options [Hash] additional options for the coercion
    # @option options [Object] :* Any coercion option key-value pairs
    #
    # @return [Object] the coerced value
    #
    # @raise [TypeError] when the type is not registered
    #
    # @example
    #   result = registry.coerce(:integer, task, "42")
    #   result = registry.coerce(:boolean, task, "true", strict: true)
    #
    # @rbs (Symbol type, untyped task, untyped value, ?Hash[Symbol, untyped] options) -> untyped
    def coerce(type, task, value, options = EMPTY_HASH)
      raise TypeError, "unknown coercion type #{type.inspect}" unless registry.key?(type)

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

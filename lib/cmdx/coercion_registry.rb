# frozen_string_literal: true

module CMDx
  # Registry for managing type coercion handlers.
  #
  # Provides a centralized way to register, deregister, and execute type coercions
  # for various data types including arrays, numbers, dates, and other primitives.
  class CoercionRegistry

    attr_reader :registry
    alias to_h registry

    # Initialize a new coercion registry.
    #
    # @param registry [Hash<Symbol, Class>, nil] optional initial registry hash
    #
    # @example
    #   registry = CoercionRegistry.new
    #   registry = CoercionRegistry.new(custom: CustomCoercion)
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

    # Create a duplicate of this registry.
    #
    # @return [CoercionRegistry] a new instance with duplicated registry hash
    #
    # @example
    #   new_registry = registry.dup
    def dup
      self.class.new(registry.dup)
    end

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
    def register(name, coercion)
      registry[name.to_sym] = coercion
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
    def deregister(name)
      registry.delete(name.to_sym)
      self
    end

    # Coerce a value to the specified type using the registered handler.
    #
    # @param type [Symbol] the type to coerce to
    # @param task [Object] the task context for the coercion
    # @param value [Object] the value to coerce
    # @param options [Hash] additional options for the coercion
    #
    # @return [Object] the coerced value
    #
    # @raise [TypeError] when the type is not registered
    #
    # @example
    #   result = registry.coerce(:integer, task, "42")
    #   result = registry.coerce(:boolean, task, "true", strict: true)
    def coerce(type, task, value, options = {})
      raise TypeError, "unknown coercion type #{type.inspect}" unless registry.key?(type)

      Utils::Call.invoke(task, registry[type], value, options)
    end

  end
end

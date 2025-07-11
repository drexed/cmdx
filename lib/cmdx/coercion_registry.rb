# frozen_string_literal: true

module CMDx
  # Registry for managing type coercion definitions and execution within tasks.
  #
  # This registry handles the registration and execution of coercions that convert
  # parameter values from one type to another, supporting both built-in types and
  # custom coercion logic.
  #
  # @since 1.0.0
  class CoercionRegistry

    # The internal hash storing coercion definitions.
    #
    # @return [Hash] hash containing coercion type keys and coercion class/callable values
    attr_reader :registry

    # Initializes a new coercion registry with default type coercions.
    #
    # Sets up the registry with built-in coercions for standard Ruby types
    # including primitives, numerics, dates, and collections.
    #
    # @return [CoercionRegistry] a new coercion registry instance
    #
    # @example Creating a new registry
    #   registry = CoercionRegistry.new
    #   registry.registry[:string] # => Coercions::String
    def initialize
      @registry = {
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
        time: Coercions::Time,
        virtual: Coercions::Virtual
      }
    end

    # Registers a custom coercion for a specific type.
    #
    # @param type [Symbol] the type identifier for the coercion
    # @param coercion [Object] the coercion callable (class, proc, symbol, or string)
    #
    # @return [CoercionRegistry] returns self for method chaining
    #
    # @example Registering a custom coercion class
    #   registry.register(:uuid, UUIDCoercion)
    #
    # @example Registering a proc coercion
    #   registry.register(:upcase, ->(value, options) { value.to_s.upcase })
    #
    # @example Chaining registrations
    #   registry.register(:custom1, MyCoercion).register(:custom2, AnotherCoercion)
    def register(type, coercion)
      registry[type] = coercion
      self
    end

    # Executes a coercion for the specified type and value.
    #
    # @param task [Task] the task instance executing the coercion
    # @param type [Symbol] the coercion type to execute
    # @param value [Object] the value to be coerced
    # @param options [Hash] additional options for the coercion
    #
    # @return [Object] the coerced value
    #
    # @raise [UnknownCoercionError] when the coercion type is not registered
    #
    # @example Coercing a string to integer
    #   registry.call(task, :integer, "42")
    #   # => 42
    #
    # @example Coercing with options
    #   registry.call(task, :array, "a,b,c", delimiter: ",")
    #   # => ["a", "b", "c"]
    def call(task, type, value, options = {})
      raise UnknownCoercionError, "unknown coercion #{type}" unless registry.key?(type)

      case coercion = registry[type]
      when Symbol, String, Proc
        task.cmdx_try(coercion, value, options)
      else
        coercion.call(value, options)
      end
    end

  end
end

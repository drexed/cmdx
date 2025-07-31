# frozen_string_literal: true

module CMDx
  # Registry for managing parameter type coercion functionality.
  #
  # CoercionRegistry provides a centralized system for storing, accessing, and
  # executing type coercions during task parameter processing. It maintains an
  # internal registry of coercion type keys mapped to their corresponding coercion
  # classes or callables, supporting both built-in framework coercions and custom
  # user-defined coercions for flexible type conversion during task execution.
  class CoercionRegistry

    # @return [Hash] hash containing coercion type keys and coercion class/callable values
    attr_reader :registry

    # Creates a new coercion registry with built-in coercion types.
    #
    # Initializes the registry with all standard framework coercions including
    # primitive types (string, integer, float, boolean), date/time types,
    # collection types (array, hash), numeric types (big_decimal, rational, complex),
    # and the virtual coercion type for parameter definitions without type conversion.
    #
    # @return [CoercionRegistry] a new registry instance with built-in coercions
    #
    # @example Create a new coercion registry
    #   registry = CoercionRegistry.new
    #   registry.registry.keys
    #   #=> [:array, :big_decimal, :boolean, :complex, :date, :datetime, :float, :hash, :integer, :rational, :string, :time, :virtual]
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

    # Registers a new coercion type in the registry.
    #
    # Adds or overwrites a coercion type mapping in the registry, allowing custom
    # coercions to be used during task parameter processing. The coercion can be
    # a class that responds to `call`, a callable object, or a symbol/string
    # representing a method to invoke on the task instance.
    #
    # @param type [Symbol] the coercion type identifier to register
    # @param coercion [Class, Proc, Symbol, String] the coercion implementation
    #
    # @return [CoercionRegistry] self for method chaining
    #
    # @example Register a custom coercion class
    #   registry.register(:temperature, TemperatureCoercion)
    #
    # @example Register a coercion proc
    #   registry.register(:upcase, proc { |value, options| value.to_s.upcase })
    #
    # @example Register a method symbol
    #   registry.register(:custom_parse, :parse_custom_format)
    def register(type, coercion)
      registry[type] = coercion
      self
    end

    # Executes a coercion by type on the provided value.
    #
    # Looks up and executes the coercion implementation for the specified type,
    # applying it to the provided value with optional configuration. Handles
    # different coercion implementation types including callable objects,
    # method symbols/strings, and coercion classes.
    #
    # @param task [CMDx::Task] the task instance for context when calling methods
    # @param type [Symbol] the coercion type to execute
    # @param value [Object] the value to be coerced
    # @param options [Hash] additional options passed to the coercion
    # @option options [Object] any any additional configuration for the coercion
    #
    # @return [Object] the coerced value
    #
    # @raise [UnknownCoercionError] when the specified coercion type is not registered
    # @raise [CoercionError] when the coercion fails to convert the value
    #
    # @example Execute a built-in coercion
    #   registry.call(task, :integer, "123")
    #   #=> 123
    #
    # @example Execute with options
    #   registry.call(task, :date, "2024-01-15", format: "%Y-%m-%d")
    #   #=> #<Date: 2024-01-15>
    #
    # @example Handle unknown coercion type
    #   registry.call(task, :unknown_type, "value")
    #   #=> raises UnknownCoercionError
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

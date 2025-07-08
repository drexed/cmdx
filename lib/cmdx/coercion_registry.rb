# frozen_string_literal: true

module CMDx
  ##
  # CoercionRegistry manages the collection of parameter coercions available within
  # CMDx tasks. It provides both built-in coercions for standard Ruby types and
  # the ability to register custom coercions for specialized type conversion needs.
  #
  # The registry combines default coercions with custom registrations, allowing
  # tasks to leverage both standard type conversions and domain-specific transformations.
  #
  # @example Basic usage with built-in coercions
  #   registry = CoercionRegistry.new
  #   registry.call(:integer, "123")  #=> 123
  #   registry.call(:boolean, "true") #=> true
  #   registry.call(:array, "[1,2,3]") #=> [1, 2, 3]
  #
  # @example Registering custom coercions
  #   registry = CoercionRegistry.new
  #   registry.register(:email, EmailCoercion.new)
  #   registry.register(:phone, proc { |value| value.gsub(/\D/, '') })
  #   registry.call(:email, "USER@EXAMPLE.COM") #=> "user@example.com"
  #
  # @example Using custom coercions with tasks
  #   class ProcessUserTask < CMDx::Task
  #     required :email, type: :email
  #     required :phone, type: :phone
  #   end
  #
  # @see Parameter Parameter type coercion integration
  # @see Task Task coercion system
  # @since 1.1.0
  class CoercionRegistry

    ##
    # @!attribute [r] registry
    #   @return [Hash] the complete registry of coercions (default + custom)
    attr_reader :registry

    ##
    # Initializes a new CoercionRegistry with optional custom coercions.
    #
    # The registry combines any provided custom coercions with the default
    # coercions, with custom coercions taking precedence for overlapping keys.
    #
    # @param registry [Hash] optional hash of custom coercions
    # @return [CoercionRegistry] new registry instance
    #
    # @example Initialize with defaults only
    #   registry = CoercionRegistry.new
    #
    # @example Initialize with custom coercions
    #   registry = CoercionRegistry.new(
    #     email: EmailCoercion,
    #     phone: PhoneCoercion.new
    #   )
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

    ##
    # Registers a custom coercion for a specific type.
    #
    # Custom coercions can be classes that respond to `call(value, options)`
    # or callable objects like procs and lambdas. Registered coercions
    # override any existing coercion for the same type.
    #
    # @param type [Symbol] the parameter type to register coercion for
    # @param coercion [#call] coercion class or callable object
    # @return [CoercionRegistry] self for method chaining
    #
    # @example Register a coercion class
    #   registry.register(:email, EmailCoercion)
    #
    # @example Register a proc coercion
    #   registry.register(:phone, proc { |value| value.gsub(/\D/, '') })
    #
    # @example Method chaining
    #   registry.register(:email, EmailCoercion)
    #           .register(:phone, PhoneCoercion.new)
    def register(type, coercion)
      registry[type] = coercion
      self
    end

    ##
    # Applies coercion to a value using the specified type.
    #
    # Looks up the coercion for the given type and applies it to the value
    # with any provided options. Raises an error if the type is not registered.
    #
    # @param type [Symbol] the coercion type to apply
    # @param value [Object] the value to coerce
    # @param options [Hash] optional parameters for the coercion
    # @return [Object] the coerced value
    # @raise [UnknownCoercionError] if the type is not registered
    #
    # @example Apply built-in coercion
    #   registry.call(:integer, "123")  #=> 123
    #   registry.call(:boolean, "true") #=> true
    #
    # @example Apply custom coercion
    #   registry.register(:email, EmailCoercion.new)
    #   registry.call(:email, "USER@EXAMPLE.COM") #=> "user@example.com"
    #
    # @example Apply coercion with options
    #   registry.call(:date, "12/25/2023", format: "%m/%d/%Y")
    def call(task, type, value, options = {})
      raise UnknownCoercionError, "unknown coercion #{type}" unless registry.key?(type)

      case coercion = registry[type]
      when Symbol, String, Proc
        task.__cmdx_try(coercion, value, options)
      else
        coercion.call(value, options)
      end
    end

  end
end

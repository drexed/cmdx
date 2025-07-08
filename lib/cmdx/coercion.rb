# frozen_string_literal: true

module CMDx
  ##
  # Base class for CMDx coercions that provides parameter type conversion capabilities.
  #
  # Coercion components convert parameter values from one type to another, enabling
  # flexible parameter handling and automatic type conversion. Each coercion must
  # implement the `call` method which receives the parameter value and coercion
  # options, returning the converted value or raising coercion errors.
  #
  # Coercions are used extensively in parameter definitions to ensure parameters
  # are in the expected format before validation and task execution.
  #
  # @example Basic coercion implementation
  #   class UppercaseCoercion < CMDx::Coercion
  #     def call(value, options = {})
  #       value.to_s.upcase
  #     end
  #   end
  #
  # @example Coercion with error handling
  #   class StrictIntegerCoercion < CMDx::Coercion
  #     def call(value, options = {})
  #       Integer(value)
  #     rescue ArgumentError, TypeError
  #       raise CMDx::CoercionError, "could not coerce into an integer"
  #     end
  #   end
  #
  # @example Coercion with configurable options
  #   class DecimalCoercion < CMDx::Coercion
  #     def call(value, options = {})
  #       precision = options[:precision] || 2
  #       BigDecimal(value.to_s).round(precision)
  #     rescue ArgumentError
  #       raise CMDx::CoercionError, "could not coerce into a decimal"
  #     end
  #   end
  #
  # @example Conditional coercion
  #   class SmartStringCoercion < CMDx::Coercion
  #     def call(value, options = {})
  #       case value
  #       when String then value
  #       when Symbol then value.to_s
  #       when nil then options[:default_for_nil] || ""
  #       else
  #         if options[:strict]
  #           raise CMDx::CoercionError, "cannot coerce #{value.class} to string in strict mode"
  #         else
  #           value.to_s
  #         end
  #       end
  #     end
  #   end
  #
  # @example Using coercions in parameter definitions
  #   class ProcessDataTask < CMDx::Task
  #     required :amount, type: :decimal, coerce: { precision: 4 }
  #     required :name, type: :string, coerce: UppercaseCoercion
  #     optional :tags, type: :array, default: []
  #   end
  #
  # @example Built-in coercion types
  #   class MyTask < CMDx::Task
  #     required :id, type: :integer        # Uses CMDx::Coercions::Integer
  #     required :active, type: :boolean     # Uses CMDx::Coercions::Boolean
  #     required :data, type: :hash          # Uses CMDx::Coercions::Hash
  #     required :tags, type: :array         # Uses CMDx::Coercions::Array
  #     required :score, type: :float        # Uses CMDx::Coercions::Float
  #     required :created_at, type: :date_time  # Uses CMDx::Coercions::DateTime
  #   end
  #
  # @see Parameter Parameter type coercion integration
  # @see ParameterValue Parameter value coercion processing
  # @see CoercionError Coercion error handling
  # @see CoercionRegistry Coercion type registration
  # @since 1.0.0
  class Coercion

    ##
    # Convenience class method for creating and calling coercion instances.
    #
    # This method provides a shortcut for coercion execution without requiring
    # explicit instantiation. It creates a new coercion instance and immediately
    # calls it with the provided value and options.
    #
    # @param value [Object] the value to coerce
    # @param options [Hash] coercion options and configuration
    # @return [Object] the coerced value
    # @raise [CoercionError] if coercion fails
    #
    # @example Direct coercion usage
    #   UppercaseCoercion.call("hello")  # => "HELLO"
    #   StrictIntegerCoercion.call("123")  # => 123
    #   StrictIntegerCoercion.call("abc")  # => raises CoercionError
    #
    # @example With coercion options
    #   DecimalCoercion.call("3.14159", precision: 2)  # => BigDecimal("3.14")
    #   SmartStringCoercion.call(nil, default_for_nil: "N/A")  # => "N/A"
    #
    # @since 1.0.0
    def self.call(value, options = {})
      new.call(value, options)
    end

    ##
    # Coerces a value to the target type using the coercion's conversion logic.
    #
    # This method must be implemented by coercion subclasses to define their
    # specific conversion logic. The method should return the converted value
    # or raise a CoercionError with an appropriate message when conversion fails.
    #
    # @param value [Object] the value to coerce
    # @param options [Hash] coercion options and configuration
    # @return [Object] the coerced value
    # @raise [CoercionError] if coercion fails
    # @raise [UndefinedCallError] if not implemented by subclass
    # @abstract Subclasses must implement this method
    #
    # @example Basic coercion implementation
    #   def call(value, options = {})
    #     return value if value.is_a?(String)
    #
    #     value.to_s
    #   rescue NoMethodError
    #     raise CMDx::CoercionError, "could not coerce #{value.class} to string"
    #   end
    #
    # @example Coercion with validation
    #   def call(value, options = {})
    #     result = Integer(value)
    #
    #     if options[:positive] && result <= 0
    #       raise CMDx::CoercionError, "coerced value must be positive"
    #     end
    #
    #     result
    #   rescue ArgumentError, TypeError
    #     raise CMDx::CoercionError, "could not coerce into an integer"
    #   end
    #
    # @example Complex coercion with multiple formats
    #   def call(value, options = {})
    #     case value
    #     when Date then value
    #     when String
    #       if options[:format]
    #         Date.strptime(value, options[:format])
    #       else
    #         Date.parse(value)
    #       end
    #     when Time then value.to_date
    #     else
    #       raise CMDx::CoercionError, "cannot coerce #{value.class} to date"
    #     end
    #   rescue Date::Error, ArgumentError
    #     raise CMDx::CoercionError, "could not coerce into a date"
    #   end
    #
    # @since 1.0.0
    def call(_value, _options = {})
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Float type.
    #
    # The Float coercion converts parameter values to Float objects
    # using Ruby's built-in Float() method, with proper error handling
    # for values that cannot be converted to floating-point numbers.
    #
    # @example Basic float coercion
    #   class ProcessOrderTask < CMDx::Task
    #     required :price, type: :float
    #     optional :discount_rate, type: :float, default: 0.0
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Float.call("123.45")   # => 123.45
    #   Coercions::Float.call("1.5e2")    # => 150.0 (scientific notation)
    #   Coercions::Float.call(42)         # => 42.0
    #   Coercions::Float.call("invalid")  # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    module Float

      module_function

      # Coerce a value to Float.
      #
      # @param value [Object] value to coerce to float
      # @param _options [Hash] coercion options (unused)
      # @return [Float] coerced float value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::Float.call("123.45")  # => 123.45
      #   Coercions::Float.call(42)        # => 42.0
      #   Coercions::Float.call("1e3")     # => 1000.0
      def call(value, _options = {})
        Float(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "float",
          default: "could not coerce into a float"
        )
      end

    end
  end
end

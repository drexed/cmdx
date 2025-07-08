# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Complex type.
    #
    # The Complex coercion converts parameter values to Complex number objects
    # using Ruby's built-in Complex() method, with proper error handling
    # for values that cannot be converted to complex numbers.
    #
    # @example Basic complex coercion
    #   class MathTask < CMDx::Task
    #     required :complex_number, type: :complex
    #     optional :coefficient, type: :complex, default: Complex(1, 0)
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Complex.call("1+2i")      # => (1+2i)
    #   Coercions::Complex.call("3-4i")      # => (3-4i)
    #   Coercions::Complex.call(5)           # => (5+0i)
    #   Coercions::Complex.call("invalid")   # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    class Complex < Coercion

      # Coerce a value to Complex.
      #
      # @param value [Object] value to coerce to complex number
      # @param _options [Hash] coercion options (unused)
      # @return [Complex] coerced complex number value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::Complex.call("1+2i")    # => (1+2i)
      #   Coercions::Complex.call(42)        # => (42+0i)
      #   Coercions::Complex.call("3.5-2i")  # => (3.5-2i)
      def call(value, _options = {})
        Complex(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "complex",
          default: "could not coerce into a complex"
        )
      end

    end
  end
end

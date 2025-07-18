# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to complex numbers.
    #
    # This coercion handles conversion of various types to complex numbers,
    # including strings, integers, floats, and other numeric types.
    class Complex < Coercion

      # Converts the given value to a complex number.
      #
      # @param value [Object] the value to convert to a complex number
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Complex] the converted complex number value
      #
      # @raise [CoercionError] if the value cannot be converted to a complex number
      #
      # @example Converting numeric values
      #   Coercions::Complex.call(5) #=> (5+0i)
      #   Coercions::Complex.call(3.14) #=> (3.14+0i)
      #
      # @example Converting string representations
      #   Coercions::Complex.call("2+3i") #=> (2+3i)
      #   Coercions::Complex.call("1-2i") #=> (1-2i)
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

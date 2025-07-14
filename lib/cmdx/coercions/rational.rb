# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to rational numbers.
    #
    # This coercion handles conversion of various types to rational numbers,
    # using Ruby's built-in Rational() method for type conversion.
    class Rational < Coercion

      # Converts the given value to a rational number.
      #
      # @param value [Object] the value to convert to a rational number
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Rational] the converted rational value
      #
      # @raise [CoercionError] if the value cannot be converted to a rational number
      #
      # @example Converting a string fraction
      #   Coercions::Rational.call('1/2') #=> (1/2)
      #
      # @example Converting an integer
      #   Coercions::Rational.call(5) #=> (5/1)
      #
      # @example Converting a float
      #   Coercions::Rational.call(0.25) #=> (1/4)
      def call(value, _options = {})
        Rational(value)
      rescue ArgumentError, FloatDomainError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "rational",
          default: "could not coerce into a rational"
        )
      end

    end
  end
end

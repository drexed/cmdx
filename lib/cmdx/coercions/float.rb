# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Float format
    #
    # Handles conversion from numeric strings, integers, and other numeric types
    # that can be converted to floats using Ruby's Float() method.
    module Float

      extend self

      # Converts a value to a Float
      #
      # @param value [Object] The value to convert to a float
      # @param options [Hash] Optional configuration parameters (currently unused)
      # @option options [Object] :unused Currently no options are used
      #
      # @return [Float] The converted float value
      #
      # @raise [CoercionError] If the value cannot be converted to a float
      #
      # @example Convert numeric strings to float
      #   Float.call("123")        # => 123.0
      #   Float.call("123.456")    # => 123.456
      #   Float.call("-42.5")      # => -42.5
      #   Float.call("1.23e4")     # => 12300.0
      # @example Convert numeric types to float
      #   Float.call(42)           # => 42.0
      #   Float.call(BigDecimal("123.456")) # => 123.456
      #   Float.call(Rational(3, 4))       # => 0.75
      #   Float.call(Complex(5.0, 0))      # => 5.0
      def call(value, options = {})
        Float(value)
      rescue ArgumentError, RangeError, TypeError
        type = Locale.t("cmdx.types.float")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

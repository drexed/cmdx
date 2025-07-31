# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to floats.
    #
    # This coercion handles conversion of various types to float values using
    # Ruby's built-in Float() method.
    class Float < Coercion

      # Converts the given value to a float.
      #
      # @param value [Object] the value to convert to a float
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Float] the converted float value
      #
      # @raise [CoercionError] if the value cannot be converted to a float
      #
      # @example Converting numeric strings
      #   Coercions::Float.call("3.14") #=> 3.14
      #   Coercions::Float.call("42") #=> 42.0
      #
      # @example Converting other numeric types
      #   Coercions::Float.call(42) #=> 42.0
      #   Coercions::Float.call(3.14) #=> 3.14
      def call(value, _options = {})
        Float(value)
      rescue ArgumentError, RangeError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "float",
          default: "could not coerce into a float"
        )
      end

    end
  end
end

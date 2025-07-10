# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to integers.
    #
    # This coercion handles conversion of various types to integers using Ruby's
    # built-in Integer() method, which provides strict type conversion.
    #
    # @since 1.0.0
    class Integer < Coercion

      # Converts the given value to an integer.
      #
      # @param value [Object] the value to convert to an integer
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Integer] the converted integer value
      #
      # @raise [CoercionError] if the value cannot be converted to an integer
      #
      # @example Converting numeric strings
      #   Coercions::Integer.call("123") #=> 123
      #   Coercions::Integer.call("-456") #=> -456
      #
      # @example Converting other numeric types
      #   Coercions::Integer.call(123.45) #=> 123
      #   Coercions::Integer.call(true) #=> 1
      #   Coercions::Integer.call(false) #=> 0
      def call(value, _options = {})
        Integer(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_an",
          type: "integer",
          default: "could not coerce into an integer"
        )
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to strings.
    #
    # This coercion handles conversion of various types to strings using Ruby's
    # built-in String() method, which provides consistent string conversion
    # behavior across different object types.
    #
    # @since 1.0.0
    class String < Coercion

      # Converts the given value to a string.
      #
      # @param value [Object] the value to convert to a string
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [String] the converted string value
      #
      # @raise [TypeError] if the value cannot be converted to a string
      #
      # @example Converting numbers
      #   Coercions::String.call(123) #=> "123"
      #   Coercions::String.call(45.67) #=> "45.67"
      #
      # @example Converting symbols and nil
      #   Coercions::String.call(:symbol) #=> "symbol"
      #   Coercions::String.call(nil) #=> ""
      #
      # @example Converting boolean values
      #   Coercions::String.call(true) #=> "true"
      #   Coercions::String.call(false) #=> "false"
      def call(value, _options = {})
        String(value)
      end

    end
  end
end

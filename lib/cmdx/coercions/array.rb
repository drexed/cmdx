# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to arrays.
    #
    # This coercion handles conversion of various types to arrays, with special
    # handling for JSON-formatted strings that start with "[".
    class Array < Coercion

      # Converts the given value to an array.
      #
      # @param value [Object] the value to convert to an array
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Array] the converted array value
      #
      # @raise [JSON::ParserError] if value is a JSON string that cannot be parsed
      # @raise [TypeError] if the value cannot be converted to an array
      #
      # @example Converting a JSON string
      #   Coercions::Array.call('["a", "b", "c"]') #=> ["a", "b", "c"]
      #
      # @example Converting other values
      #   Coercions::Array.call("hello") #=> ["hello"]
      #   Coercions::Array.call(123) #=> [123]
      #   Coercions::Array.call(nil) #=> []
      def call(value, _options = {})
        if value.is_a?(::String) && value.start_with?("[")
          JSON.parse(value)
        else
          Array(value)
        end
      end

    end
  end
end

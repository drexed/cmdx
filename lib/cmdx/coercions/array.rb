# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Array format
    #
    # Handles conversion from strings that look like JSON arrays and other
    # values that can be converted to arrays using Ruby's Array() method.
    module Array

      extend self

      # Converts a value to an Array
      #
      # @param value [Object] The value to convert to an array
      # @param options [Hash] Optional configuration parameters (currently unused)
      # @option options [Object] :unused Currently no options are used
      #
      # @return [Array] The converted array value
      #
      # @raise [JSON::ParserError] If the string value contains invalid JSON
      #
      # @example Convert a JSON-like string to an array
      #   call("[1, 2, 3]") # => [1, 2, 3]
      # @example Convert other values using Array()
      #   call("hello")     # => ["hello"]
      #   call(42)          # => [42]
      #   call(nil)         # => []
      def call(value, options = {})
        if value.is_a?(::String) && value.start_with?("[")
          JSON.parse(value)
        else
          Array(value)
        end
      end

    end
  end
end

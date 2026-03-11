# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Array format
    #
    # Handles conversion from strings that look like JSON arrays and other
    # values that can be wrapped in an array using Ruby's Array() method.
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
      # @raise [CoercionError] If the value cannot be converted to an array
      #
      # @example Convert a JSON-like string to an array
      #   Array.call("[1, 2, 3]") # => [1, 2, 3]
      # @example Convert other values using Array()
      #   Array.call("hello")     # => ["hello"]
      #   Array.call(42)          # => [42]
      #   Array.call(nil)         # => []
      # @example Handle invalid JSON-like strings
      #   Array.call("[not json") # => raises CoercionError
      #
      # @rbs (untyped value, ?Hash[Symbol, untyped] options) -> Array[untyped]
      def call(value, options = {})
        if value.is_a?(::String) && (
          value.start_with?("[") ||
          value.strip == "null"
        )
          JSON.parse(value) || []
        else
          Utils::Wrap.array(value)
        end
      rescue JSON::ParserError
        type = Locale.t("cmdx.types.array")
        raise CoercionError, Locale.t("cmdx.coercions.into_an", type:)
      end

    end
  end
end

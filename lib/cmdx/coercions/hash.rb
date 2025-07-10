# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to hashes.
    #
    # This coercion handles conversion of various types to hashes, with special
    # handling for JSON-formatted strings that start with "{" and array-to-hash
    # conversion using array splatting.
    #
    # @since 1.0.0
    class Hash < Coercion

      # Converts the given value to a hash.
      #
      # @param value [Object] the value to convert to a hash
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Hash] the converted hash value
      #
      # @raise [CoercionError] if the value cannot be converted to a hash
      # @raise [JSON::ParserError] if value is a JSON string that cannot be parsed
      # @raise [ArgumentError] if array cannot be converted to hash pairs
      # @raise [TypeError] if the value type is not supported
      #
      # @example Converting a JSON string
      #   Coercions::Hash.call('{"a": 1, "b": 2}') #=> {"a" => 1, "b" => 2}
      #
      # @example Converting an array to hash
      #   Coercions::Hash.call(["a", 1, "b", 2]) #=> {"a" => 1, "b" => 2}
      #
      # @example Passing through existing hashes
      #   Coercions::Hash.call({"key" => "value"}) #=> {"key" => "value"}
      def call(value, _options = {})
        case value.class.name
        when "Hash", "ActionController::Parameters"
          value
        when "Array"
          ::Hash[*value]
        when "String"
          value.start_with?("{") ? JSON.parse(value) : raise_coercion_error!
        else
          raise_coercion_error!
        end
      rescue ArgumentError, TypeError, JSON::ParserError
        raise_coercion_error!
      end

      private

      def raise_coercion_error!
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "hash",
          default: "could not coerce into a hash"
        )
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces various input types into Hash objects
    #
    # Supports conversion from:
    # - Nil values (converted to empty Hash)
    # - Hash objects (returned as-is)
    # - Array objects (converted using Hash[*array])
    # - JSON strings starting with "{" (parsed into Hash)
    # - Other types raise CoercionError
    module Hash

      extend self

      # Coerces a value into a Hash
      #
      # @param value [Object] The value to coerce
      # @param options [Hash] Additional options (currently unused)
      # @option options [Symbol] :strict Whether to enforce strict conversion
      #
      # @return [Hash] The coerced hash value
      #
      # @raise [CoercionError] When the value cannot be coerced to a Hash
      #
      # @example Coerce from existing Hash
      #   Hash.call({a: 1, b: 2}) # => {a: 1, b: 2}
      # @example Coerce from Array
      #   Hash.call([:a, 1, :b, 2]) # => {a: 1, b: 2}
      # @example Coerce from JSON string
      #   Hash.call('{"key": "value"}') # => {"key" => "value"}
      #
      # @rbs (untyped value, ?Hash[Symbol, untyped] options) -> Hash[untyped, untyped]
      def call(value, options = {})
        if value.nil?
          {}
        elsif value.is_a?(::Hash)
          value
        elsif value.is_a?(::Array)
          ::Hash[*value]
        elsif value.is_a?(::String) && (
          value.start_with?("{") ||
          value.strip == "null"
        )
          JSON.parse(value) || {}
        elsif value.respond_to?(:to_h)
          value.to_h
        else
          raise_coercion_error!
        end
      rescue ArgumentError, TypeError, JSON::ParserError
        raise_coercion_error!
      end

      private

      # Raises a CoercionError with localized message
      #
      # @raise [CoercionError] Always raised with localized error message
      def raise_coercion_error!
        type = Locale.t("cmdx.types.hash")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

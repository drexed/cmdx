# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Array. JSON-decodes strings; arrays pass through; objects
    # responding to `#to_a` are unwrapped; everything else is wrapped.
    module Array

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Object] reserved for future per-coercion configuration (currently ignored)
      # @return [Array, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        if value.is_a?(::Array)
          value
        elsif value.is_a?(::String)
          result = JSON.parse(value)
          result.is_a?(::Array) ? result : [value]
        elsif value.respond_to?(:to_a)
          value.to_a
        else
          [value]
        end
      rescue JSON::ParserError
        [value]
      rescue TypeError
        type = I18nProxy.t("cmdx.types.array")
        Failure.new(I18nProxy.t("cmdx.coercions.into_an", type:))
      end

    end
  end
end

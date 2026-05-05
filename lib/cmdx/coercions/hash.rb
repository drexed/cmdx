# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Hash. `nil` becomes `{}`; strings are JSON-decoded (and
    # must decode to a Hash); `#to_hash`/`#to_h` are used as fallbacks.
    module Hash

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Object] reserved for future per-coercion configuration (currently ignored)
      # @return [Hash, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        if value.nil?
          {}
        elsif value.is_a?(::Hash)
          value
        elsif value.is_a?(::String)
          result = JSON.parse(value)
          result.is_a?(::Hash) ? result : coercion_failure
        elsif value.respond_to?(:to_hash)
          value.to_hash
        elsif value.respond_to?(:to_h)
          value.to_h
        else
          coercion_failure
        end
      rescue ArgumentError, TypeError, JSON::ParserError
        coercion_failure
      end

      private

      def coercion_failure
        type = I18nProxy.t("cmdx.types.hash")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

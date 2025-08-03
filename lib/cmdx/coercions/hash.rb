# frozen_string_literal: true

module CMDx
  module Coercions
    module Hash

      extend self

      def call(value, options = {})
        if value.is_a?(::Hash)
          value
        elsif value.is_a?(::Array)
          ::Hash[*value]
        elsif value.is_a?(::String) && value.start_with?("{")
          JSON.parse(value)
        else
          raise_coercion_error!
        end
      rescue ArgumentError, TypeError, JSON::ParserError
        raise_coercion_error!
      end

      private

      def raise_coercion_error!
        type = Utils::Locale.translate("cmdx.types.hash")
        raise CoercionError, Utils::Locale.translate("cmdx.coercions.into_a", type:)
      end

    end
  end
end

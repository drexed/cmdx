# frozen_string_literal: true

module CMDx
  module Coercions
    module Hash

      extend self

      def call(value, options = {})
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
        type = Utils::Locale.t("cmdx.types.hash")
        raise CoercionError, Utils::Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    module Hash

      extend self

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

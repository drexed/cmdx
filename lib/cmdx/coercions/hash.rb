# frozen_string_literal: true

module CMDx
  module Coercions
    module Hash

      extend self

      def call(value, _options = {})
        case value.class.name
        when "Hash", "ActionController::Parameters" then value
        when "Array" then ::Hash[*value]
        else raise_coercion_error!
        end
      rescue ArgumentError, TypeError
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

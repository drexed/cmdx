# frozen_string_literal: true

module CMDx
  module Coercions
    module Boolean

      FALSEY = /^(false|f|no|n|0)$/i
      TRUTHY = /^(true|t|yes|y|1)$/i

      extend self

      def call(value, options = {})
        case value.to_s.downcase
        when FALSEY then false
        when TRUTHY then true
        else
          type = Utils::Locale.translate("cmdx.types.boolean")
          raise CoercionError, Utils::Locale.translate("cmdx.coercions.into_a", type:)
        end
      end

    end
  end
end

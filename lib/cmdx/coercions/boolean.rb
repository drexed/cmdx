# frozen_string_literal: true

module CMDx
  module Coercions
    module Boolean

      FALSEY = /^(false|f|no|n|0)$/i
      TRUTHY = /^(true|t|yes|y|1)$/i

      module_function

      def call(value, options = {}) # rubocop:disable Lint/UnusedMethodArgument
        case value.to_s.downcase
        when FALSEY then false
        when TRUTHY then true
        else
          raise CoercionError, I18n.t(
            "cmdx.coercions.into_a",
            type: "boolean",
            default: "could not coerce into a boolean"
          )
        end
      end

    end
  end
end

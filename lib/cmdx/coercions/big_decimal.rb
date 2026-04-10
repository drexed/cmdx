# frozen_string_literal: true

module CMDx
  module Coercions
    module BigDecimal

      # @rbs (untyped value) -> BigDecimal
      def self.call(value)
        return value if value.is_a?(::BigDecimal)

        Kernel.BigDecimal(value.to_s)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.big_decimal"))
      end

    end
  end
end

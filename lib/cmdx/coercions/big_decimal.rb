# frozen_string_literal: true

module CMDx
  module Coercions
    module BigDecimal

      DEFAULT_PRECISION = 14

      extend self

      def call(value, options = {})
        BigDecimal(value, options[:precision] || DEFAULT_PRECISION)
      rescue ArgumentError, TypeError
        type = Utils::Locale.t("cmdx.types.big_decimal")
        raise CoercionError, Utils::Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

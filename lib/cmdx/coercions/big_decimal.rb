# frozen_string_literal: true

module CMDx
  module Coercions
    module BigDecimal

      DEFAULT_PRECISION = 14

      module_function

      def call(value, options = {})
        BigDecimal(value, options[:precision] || DEFAULT_PRECISION)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "big decimal",
          default: "could not coerce into a big decimal"
        )
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a BigDecimal.
    module BigDecimal

      # @param value [Object]
      # @return [BigDecimal]
      #
      # @rbs (untyped value) -> BigDecimal
      def self.call(value)
        case value
        when ::BigDecimal then value
        when ::Float, ::Integer, ::Rational
          Kernel.BigDecimal(value, 0)
        when ::String
          Kernel.BigDecimal(value)
        else
          Kernel.BigDecimal(value.to_s)
        end
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "big decimal")
      end

    end
  end
end

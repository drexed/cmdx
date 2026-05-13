# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to `BigDecimal`. Default precision is 14 digits; override with
    # `precision:` on the declaration.
    module BigDecimal

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Integer] :precision (14)
      # @return [BigDecimal, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        return value if value.is_a?(::BigDecimal)

        BigDecimal(value, options[:precision] || 14)
      rescue ArgumentError, TypeError
        type = I18nProxy.t("cmdx.types.big_decimal")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

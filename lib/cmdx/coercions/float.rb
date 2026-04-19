# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Float via `Kernel#Float` (strict parsing; no silent zero).
    module Float

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}] unused
      # @return [Float, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        Float(value)
      rescue ArgumentError, RangeError, TypeError
        type = I18nProxy.t("cmdx.types.float")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

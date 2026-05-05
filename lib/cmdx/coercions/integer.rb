# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Integer via `Kernel#Integer` (strict; rejects floats-as-strings).
    module Integer

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Object] reserved for future per-coercion configuration (currently ignored)
      # @return [Integer, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        Integer(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError
        type = I18nProxy.t("cmdx.types.integer")
        Failure.new(I18nProxy.t("cmdx.coercions.into_an", type:))
      end

    end
  end
end

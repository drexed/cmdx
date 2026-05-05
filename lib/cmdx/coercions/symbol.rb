# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Symbol via `#to_s.to_sym`. Fails only when `value` has no
    # `#to_s` (i.e. `BasicObject` instances).
    module Symbol

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Object] reserved for future per-coercion configuration (currently ignored)
      # @return [Symbol, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        return value if value.is_a?(::Symbol)

        value.to_s.to_sym
      rescue NoMethodError
        type = I18nProxy.t("cmdx.types.symbol")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

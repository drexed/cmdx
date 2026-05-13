# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Integer via `Kernel#Integer` (strict; rejects floats-as-strings).
    # Pass `base:` to parse strings written in non-decimal radix
    # (e.g. `"0x10"` with `base: 16`). The `:base` option is applied only
    # when `value` is a String — for numeric inputs `Kernel#Integer` is
    # called without a base, matching its native contract.
    module Integer

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Integer] :base radix for string parsing (default 10)
      # @return [Integer, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        base = options[:base]
        if base && value.is_a?(::String)
          Integer(value, base)
        else
          Integer(value)
        end
      rescue ArgumentError, FloatDomainError, RangeError, TypeError
        type = I18nProxy.t("cmdx.types.integer")
        Failure.new(I18nProxy.t("cmdx.coercions.into_an", type:))
      end

    end
  end
end

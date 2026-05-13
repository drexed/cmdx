# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Symbol via `#to_s.to_sym`. Fails when `value` has no
    # `#to_s` (i.e. `BasicObject` instances) or when the resulting string
    # exceeds {MAX_LENGTH} characters.
    #
    # Symbols are never garbage-collected when interned from arbitrary
    # strings, so unbounded coercion of attacker-controlled input would
    # grow the symbol table unbounded (memory DoS). The default cap is
    # generous for legitimate identifiers; pass `max_length:` to tighten
    # it for hot paths or untrusted boundaries.
    module Symbol

      extend self

      MAX_LENGTH = 256

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Integer] :max_length (256) reject strings longer than this
      # @return [Symbol, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        return value if value.is_a?(::Symbol)

        str   = value.to_s
        limit = options[:max_length] || MAX_LENGTH
        return coercion_failure if str.length > limit

        str.to_sym
      rescue NoMethodError
        coercion_failure
      end

      private

      def coercion_failure
        type = I18nProxy.t("cmdx.types.symbol")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

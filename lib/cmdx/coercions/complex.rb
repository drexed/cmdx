# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to `Complex`. Supply `imaginary:` to provide the imaginary
    # component when `value` is a real-only input.
    module Complex

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Numeric] :imaginary (0)
      # @return [Complex, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        return value if value.is_a?(::Complex)

        Complex(value, options[:imaginary] || 0)
      rescue ArgumentError, TypeError
        type = I18nProxy.t("cmdx.types.complex")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

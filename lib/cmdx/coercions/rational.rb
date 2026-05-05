# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to `Rational`. Supply `denominator:` to build a rational from
    # a numerator and a custom denominator.
    module Rational

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Numeric] :denominator (1)
      # @return [Rational, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        return value if value.is_a?(::Rational)

        Rational(value, options[:denominator] || 1)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError, ZeroDivisionError
        type = I18nProxy.t("cmdx.types.rational")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

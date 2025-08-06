# frozen_string_literal: true

module CMDx
  module Coercions
    module Rational

      extend self

      def call(value, options = {})
        Rational(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError, ZeroDivisionError
        type = Locale.t("cmdx.types.rational")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

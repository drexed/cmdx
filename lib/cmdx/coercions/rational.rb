# frozen_string_literal: true

module CMDx
  module Coercions
    module Rational

      extend self

      def call(value, options = {})
        Rational(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError, ZeroDivisionError # rubocop:disable Lint/ShadowedException
        type = Locale.translate("cmdx.types.rational")
        raise CoercionError, Locale.translate("cmdx.coercions.into_a", type:)
      end

    end
  end
end

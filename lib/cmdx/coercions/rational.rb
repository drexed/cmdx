# frozen_string_literal: true

module CMDx
  module Coercions
    module Rational

      module_function

      def call(value, options = {})
        Rational(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError, ZeroDivisionError # rubocop:disable Lint/ShadowedException
        type = Utils::Locale.t("cmdx.types.rational")
        raise CoercionError, Utils::Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

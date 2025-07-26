# frozen_string_literal: true

module CMDx
  module Coercions
    module Rational

      module_function

      def call(value, options = {}) # rubocop:disable Lint/UnusedMethodArgument
        Rational(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError, ZeroDivisionError # rubocop:disable Lint/ShadowedException
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "rational",
          default: "could not coerce into a rational"
        )
      end

    end
  end
end

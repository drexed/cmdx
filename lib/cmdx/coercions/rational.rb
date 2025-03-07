# frozen_string_literal: true

module CMDx
  module Coercions
    module Rational

      module_function

      def call(value, _options = {})
        Rational(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "rational",
          default: "could not coerce into a rational"
        )
      end

    end
  end
end

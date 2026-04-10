# frozen_string_literal: true

module CMDx
  module Coercions
    module Rational

      # @rbs (untyped value) -> Rational
      def self.call(value)
        return value if value.is_a?(::Rational)

        Kernel.Rational(value)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.rational"))
      end

    end
  end
end

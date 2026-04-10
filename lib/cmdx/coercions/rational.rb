# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a Rational.
    module Rational

      # @param value [Object]
      # @return [Rational]
      #
      # @rbs (untyped value) -> Rational
      def self.call(value)
        case value
        when ::Rational then value
        else Kernel.Rational(value)
        end
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "rational")
      end

    end
  end
end

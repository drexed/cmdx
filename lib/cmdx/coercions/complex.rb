# frozen_string_literal: true

module CMDx
  module Coercions
    module Complex

      extend self

      def call(value, options = {})
        Complex(value)
      rescue ArgumentError, TypeError
        type = Utils::Locale.t("cmdx.types.complex")
        raise CoercionError, Utils::Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

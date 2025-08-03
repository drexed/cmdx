# frozen_string_literal: true

module CMDx
  module Coercions
    module Complex

      extend self

      def call(value, options = {})
        Complex(value)
      rescue ArgumentError, TypeError
        type = Locale.translate("cmdx.types.complex")
        raise CoercionError, Locale.translate("cmdx.coercions.into_a", type:)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    module Float

      extend self

      def call(value, options = {})
        Float(value)
      rescue ArgumentError, RangeError, TypeError
        type = Locale.translate("cmdx.types.float")
        raise CoercionError, Locale.translate("cmdx.coercions.into_a", type:)
      end

    end
  end
end

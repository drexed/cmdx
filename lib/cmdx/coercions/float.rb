# frozen_string_literal: true

module CMDx
  module Coercions
    module Float

      extend self

      def call(value, options = {})
        Float(value)
      rescue ArgumentError, RangeError, TypeError
        type = Utils::Locale.translate("cmdx.types.float")
        raise CoercionError, Utils::Locale.translate("cmdx.coercions.into_a", type:)
      end

    end
  end
end

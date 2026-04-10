# frozen_string_literal: true

module CMDx
  module Coercions
    module Float

      # @rbs (untyped value) -> Float
      def self.call(value)
        return value if value.is_a?(::Float)

        Kernel.Float(value)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.float"))
      end

    end
  end
end

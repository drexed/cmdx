# frozen_string_literal: true

module CMDx
  module Coercions
    module Array

      # @rbs (untyped value) -> Array[untyped]
      def self.call(value)
        return value if value.is_a?(::Array)

        Kernel.Array(value)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_an", type: Locale.t("cmdx.types.array"))
      end

    end
  end
end

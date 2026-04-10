# frozen_string_literal: true

module CMDx
  module Coercions
    module Complex

      # @rbs (untyped value) -> Complex
      def self.call(value)
        return value if value.is_a?(::Complex)

        Kernel.Complex(value)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.complex"))
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    module Integer

      # @rbs (untyped value) -> Integer
      def self.call(value)
        return value if value.is_a?(::Integer)

        Kernel.Integer(value)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_an", type: Locale.t("cmdx.types.integer"))
      end

    end
  end
end

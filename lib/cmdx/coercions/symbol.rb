# frozen_string_literal: true

module CMDx
  module Coercions
    module Symbol

      # @rbs (untyped value) -> Symbol
      def self.call(value)
        return value if value.is_a?(::Symbol)

        value.to_s.to_sym
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.symbol"))
      end

    end
  end
end

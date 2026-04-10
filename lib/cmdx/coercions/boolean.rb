# frozen_string_literal: true

module CMDx
  module Coercions
    module Boolean

      TRUTHY = [true, 1, "1", "t", "true", "y", "yes", "on"].freeze
      FALSY = [false, 0, "0", "f", "false", "n", "no", "off", nil].freeze

      # @rbs (untyped value) -> bool
      def self.call(value)
        normalized = value.is_a?(::String) ? value.downcase.strip : value
        return true if TRUTHY.include?(normalized)
        return false if FALSY.include?(normalized)

        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.boolean"))
      end

    end
  end
end

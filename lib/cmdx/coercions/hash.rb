# frozen_string_literal: true

module CMDx
  module Coercions
    module Hash

      # @rbs (untyped value) -> Hash[untyped, untyped]
      def self.call(value)
        return value if value.is_a?(::Hash)

        if value.respond_to?(:to_h)
          value.to_h
        elsif value.respond_to?(:to_hash)
          value.to_hash
        else
          raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.hash"))
        end
      rescue StandardError => e
        raise e if e.is_a?(CoercionError)

        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.hash"))
      end

    end
  end
end

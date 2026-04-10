# frozen_string_literal: true

module CMDx
  module Coercions
    module Time

      # @rbs (untyped value) -> Time
      def self.call(value)
        return value if value.is_a?(::Time) && !value.is_a?(::DateTime)

        ::Time.parse(value.to_s)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.time"))
      end

    end
  end
end

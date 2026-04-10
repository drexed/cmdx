# frozen_string_literal: true

module CMDx
  module Coercions
    module Date

      # @rbs (untyped value) -> Date
      def self.call(value)
        return value if value.is_a?(::Date) && !value.is_a?(::DateTime)

        ::Date.parse(value.to_s)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.date"))
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    module DateTime

      # @rbs (untyped value) -> DateTime
      def self.call(value)
        return value if value.is_a?(::DateTime)

        ::DateTime.parse(value.to_s)
      rescue StandardError
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type: Locale.t("cmdx.types.date_time"))
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a String.
    module String

      # @param value [Object]
      # @return [String]
      #
      # @rbs (untyped value) -> String
      def self.call(value)
        Kernel.String(value)
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "string")
      end

    end
  end
end

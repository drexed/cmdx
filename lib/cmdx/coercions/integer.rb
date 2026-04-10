# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into an Integer.
    module Integer

      # @param value [Object]
      # @return [Integer]
      #
      # @rbs (untyped value) -> Integer
      def self.call(value)
        Kernel.Integer(value)
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_an", type: "integer")
      end

    end
  end
end

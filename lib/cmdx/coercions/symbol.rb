# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a Symbol.
    module Symbol

      # @param value [Object]
      # @return [Symbol]
      #
      # @rbs (untyped value) -> Symbol
      def self.call(value)
        value.to_sym
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "symbol")
      end

    end
  end
end

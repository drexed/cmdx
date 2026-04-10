# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a Float.
    module Float

      # @param value [Object]
      # @return [Float]
      #
      # @rbs (untyped value) -> Float
      def self.call(value)
        Kernel.Float(value)
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "float")
      end

    end
  end
end

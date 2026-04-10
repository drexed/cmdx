# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a Complex number.
    module Complex

      # @param value [Object]
      # @return [Complex]
      #
      # @rbs (untyped value) -> Complex
      def self.call(value)
        case value
        when ::Complex then value
        else Kernel.Complex(value)
        end
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "complex")
      end

    end
  end
end

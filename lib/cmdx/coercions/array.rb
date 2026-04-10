# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into an Array.
    module Array

      # @param value [Object]
      # @return [Array]
      #
      # @rbs (untyped value) -> Array[untyped]
      def self.call(value)
        case value
        when ::Array then value
        when ::Hash  then value.to_a
        when nil     then []
        else Kernel.Array(value)
        end
      rescue StandardError
        raise_coercion_error!("array")
      end

      def self.raise_coercion_error!(type)
        raise Error, Locale.t("cmdx.coercions.into_an", type:)
      end

    end
  end
end

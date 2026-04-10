# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a Hash.
    module Hash

      # @param value [Object]
      # @return [Hash]
      #
      # @rbs (untyped value) -> Hash[untyped, untyped]
      def self.call(value)
        case value
        when ::Hash  then value
        when ::Array then value.to_h
        else
          return value.to_h if value.respond_to?(:to_h)

          raise Error, Locale.t("cmdx.coercions.into_a", type: "hash")
        end
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "hash")
      end

    end
  end
end

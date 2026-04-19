# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Boolean by matching the string form against the {TRUTHY}
    # and {FALSEY} sets (case- and whitespace-insensitive). Anything else
    # (including `nil`) fails.
    module Boolean

      extend self

      TRUTHY = Set["true", "yes", "on", "y", "1", "t"].freeze
      FALSEY = Set["false", "no", "off", "n", "0", "f"].freeze

      # @param value [Object]
      # @param options [Hash{Symbol => Object}] unused
      # @return [Boolean, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        return coercion_failure if value.nil?

        str = value.to_s.strip.downcase
        return true if TRUTHY.include?(str)
        return false if FALSEY.include?(str)

        coercion_failure
      end

      private

      def coercion_failure
        type = I18nProxy.t("cmdx.types.boolean")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

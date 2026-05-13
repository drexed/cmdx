# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to Boolean by matching the string form against the {TRUTHY}
    # and {FALSEY} sets (case- and whitespace-insensitive). `nil` becomes
    # `false`; anything else unrecognized fails.
    module Boolean

      extend self

      TRUTHY = Set["true", "yes", "on", "y", "1", "t"].freeze
      FALSEY = Set["false", "no", "off", "n", "0", "f"].freeze

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Object] reserved for future per-coercion configuration (currently ignored)
      # @return [Boolean, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        return false if value.nil?

        str = value.to_s.strip.downcase
        return true if TRUTHY.include?(str)
        return false if FALSEY.include?(str)

        type = I18nProxy.t("cmdx.types.boolean")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end

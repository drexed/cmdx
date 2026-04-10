# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces a value into a Boolean (true/false).
    module Boolean

      # @rbs TRUTHY: Array[untyped]
      TRUTHY = [true, 1, "1", "true", "yes", "on", "t", "y"].freeze

      # @rbs FALSY: Array[untyped]
      FALSY = [false, 0, "0", "false", "no", "off", "f", "n", nil].freeze

      # @param value [Object]
      # @return [Boolean]
      #
      # @rbs (untyped value) -> bool
      def self.call(value)
        return true if TRUTHY.include?(value)
        return false if FALSY.include?(value)

        !!value
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to String via `Kernel#String`. Never fails for normal objects.
    module String

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [Object] reserved for future per-coercion configuration (currently ignored)
      # @return [String]
      def call(value, options = EMPTY_HASH)
        String(value)
      end

    end
  end
end

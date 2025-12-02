# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Boolean format
    #
    # Handles conversion from strings, numbers, and other values to boolean
    # using predefined truthy and falsey patterns.
    module Boolean

      extend self

      # @rbs FALSEY: Regexp
      FALSEY = /\A(false|f|no|n|0)\z/i

      # @rbs TRUTHY: Regexp
      TRUTHY = /\A(true|t|yes|y|1)\z/i

      # Converts a value to a Boolean
      #
      # @param value [Object] The value to convert to boolean
      # @param options [Hash] Optional configuration parameters (currently unused)
      # @option options [Object] :unused Currently no options are used
      #
      # @return [Boolean] The converted boolean value
      #
      # @raise [CoercionError] If the value cannot be converted to boolean
      #
      # @example Convert truthy strings to true
      #   Boolean.call("true")   # => true
      #   Boolean.call("yes")    # => true
      #   Boolean.call("1")      # => true
      # @example Convert falsey strings to false
      #   Boolean.call("false")  # => false
      #   Boolean.call("no")     # => false
      #   Boolean.call("0")      # => false
      # @example Handle case-insensitive input
      #   Boolean.call("TRUE")   # => true
      #   Boolean.call("False")  # => false
      #
      # @rbs (untyped value, ?Hash[Symbol, untyped] options) -> bool
      def call(value, options = {})
        case value.to_s
        when FALSEY then false
        when TRUTHY then true
        else
          type = Locale.t("cmdx.types.boolean")
          raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
        end
      end

    end
  end
end

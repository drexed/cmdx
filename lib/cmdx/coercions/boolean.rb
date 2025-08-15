# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Boolean format
    #
    # Handles conversion from strings, numbers, and other values to boolean
    # using predefined truthy and falsey patterns.
    module Boolean

      extend self

      FALSEY = /^(false|f|no|n|0)$/i
      TRUTHY = /^(true|t|yes|y|1)$/i

      # Converts a value to a Boolean
      #
      # @param value [Object] The value to convert to boolean
      # @param options [Hash] Optional configuration parameters (currently unused)
      # @option options [Object] :unused Currently no options are used
      # @return [Boolean] The converted boolean value
      # @raise [CoercionError] If the value cannot be converted to boolean
      # @example Convert truthy strings to true
      #   call("true")   # => true
      #   call("yes")    # => true
      #   call("1")      # => true
      # @example Convert falsey strings to false
      #   call("false")  # => false
      #   call("no")     # => false
      #   call("0")      # => false
      # @example Handle case-insensitive input
      #   call("TRUE")   # => true
      #   call("False")  # => false
      def call(value, options = {})
        case value.to_s.downcase
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

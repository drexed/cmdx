# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to booleans.
    #
    # This coercion handles conversion of various string representations to
    # boolean values, supporting common true/false variations like "yes/no",
    # "1/0", and "t/f".
    #
    # @since 1.0.0
    class Boolean < Coercion

      FALSEY = /^(false|f|no|n|0)$/i
      TRUTHY = /^(true|t|yes|y|1)$/i

      # Converts the given value to a boolean.
      #
      # @param value [Object] the value to convert to a boolean
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Boolean] the converted boolean value
      #
      # @raise [CoercionError] if the value cannot be converted to a boolean
      #
      # @example Converting truthy values
      #   Coercions::Boolean.call('true') #=> true
      #   Coercions::Boolean.call('yes') #=> true
      #   Coercions::Boolean.call('1') #=> true
      #
      # @example Converting falsey values
      #   Coercions::Boolean.call('false') #=> false
      #   Coercions::Boolean.call('no') #=> false
      #   Coercions::Boolean.call('0') #=> false
      def call(value, _options = {})
        case value.to_s.downcase
        when FALSEY then false
        when TRUTHY then true
        else
          raise CoercionError, I18n.t(
            "cmdx.coercions.into_a",
            type: "boolean",
            default: "could not coerce into a boolean"
          )
        end
      end

    end
  end
end

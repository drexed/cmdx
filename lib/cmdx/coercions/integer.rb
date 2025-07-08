# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Integer type.
    #
    # The Integer coercion converts parameter values to Integer objects
    # using Ruby's built-in Integer() method, with proper error handling
    # for values that cannot be converted.
    #
    # @example Basic integer coercion
    #   class ProcessOrderTask < CMDx::Task
    #     required :order_id, type: :integer
    #     optional :quantity, type: :integer, default: 1
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Integer.call("123")     # => 123
    #   Coercions::Integer.call("0x10")    # => 16 (hex)
    #   Coercions::Integer.call("0b1010")  # => 10 (binary)
    #   Coercions::Integer.call(45.7)      # => 45 (truncated)
    #   Coercions::Integer.call("invalid") # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    class Integer < Coercion

      # Coerce a value to Integer.
      #
      # @param value [Object] value to coerce to integer
      # @param _options [Hash] coercion options (unused)
      # @return [Integer] coerced integer value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::Integer.call("123")   # => 123
      #   Coercions::Integer.call(45.9)    # => 45
      #   Coercions::Integer.call("0xFF")  # => 255
      def call(value, _options = {})
        Integer(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_an",
          type: "integer",
          default: "could not coerce into an integer"
        )
      end

    end
  end
end

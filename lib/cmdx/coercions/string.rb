# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to String type.
    #
    # The String coercion converts parameter values to String objects
    # using Ruby's built-in String() method, which handles various
    # input types safely.
    #
    # @example Basic string coercion
    #   class ProcessOrderTask < CMDx::Task
    #     required :order_id, type: :string
    #     optional :notes, type: :string
    #   end
    #
    # @example Coercion behavior
    #   Coercions::String.call(123)        # => "123"
    #   Coercions::String.call(:symbol)    # => "symbol"
    #   Coercions::String.call(true)       # => "true"
    #   Coercions::String.call(nil)        # => ""
    #   Coercions::String.call([1, 2])     # => "12" (array to_s)
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    class String < Coercion

      # Coerce a value to String.
      #
      # @param value [Object] value to coerce to string
      # @param _options [Hash] coercion options (unused)
      # @return [String] coerced string value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::String.call(123)    # => "123"
      #   Coercions::String.call(:test)  # => "test"
      def call(value, _options = {})
        String(value)
      end

    end
  end
end

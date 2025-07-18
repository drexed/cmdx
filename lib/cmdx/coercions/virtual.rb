# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for virtual values that performs no conversion.
    #
    # This coercion acts as a pass-through, returning the input value unchanged.
    # It's useful when you want to maintain the original value type and format
    # without any transformation.
    class Virtual < Coercion

      # Returns the given value unchanged.
      #
      # @param value [Object] the value to return as-is
      # @param _options [Hash] optional configuration (currently unused)
      #
      # @return [Object] the original value without any conversion
      #
      # @example Returning values unchanged
      #   Coercions::Virtual.call("hello") #=> "hello"
      #   Coercions::Virtual.call(123) #=> 123
      #   Coercions::Virtual.call(nil) #=> nil
      def call(value, _options = {})
        value
      end

    end
  end
end

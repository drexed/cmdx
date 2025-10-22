# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Integer format
    #
    # Handles conversion from strings, numbers, and other values to integers
    # using Ruby's Integer() method. Raises CoercionError for values that
    # cannot be converted to integers.
    module Integer

      extend self

      # Converts a value to an Integer
      #
      # @param value [Object] The value to convert to an integer
      # @param options [Hash] Optional configuration parameters (currently unused)
      # @option options [Object] :unused Currently no options are used
      #
      # @return [Integer] The converted integer value
      #
      # @raise [CoercionError] If the value cannot be converted to an integer
      #
      # @example Convert numeric strings to integers
      #   Integer.call("42")      # => 42
      #   Integer.call("-123")    # => -123
      #   Integer.call("0")       # => 0
      # @example Convert numeric types to integers
      #   Integer.call(42.0)      # => 42
      #   Integer.call(3.14)      # => 3
      #   Integer.call(0.0)       # => 0
      # @example Handle edge cases
      #   Integer.call("")        # => 0
      #   Integer.call(nil)       # => 0
      #   Integer.call(false)     # => 0
      #   Integer.call(true)      # => 1
      #
      # @rbs (untyped value, ?Hash[Symbol, untyped] options) -> Integer
      def call(value, options = {})
        Integer(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError
        type = Locale.t("cmdx.types.integer")
        raise CoercionError, Locale.t("cmdx.coercions.into_an", type:)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Rational format
    #
    # Handles conversion from strings, numbers, and other values to rational
    # numbers using Ruby's Rational() method. Raises CoercionError for values
    # that cannot be converted to rational numbers.
    module Rational

      extend self

      # Converts a value to a Rational
      #
      # @param value [Object] The value to convert to a rational number
      # @param options [Hash] Optional configuration parameters (currently unused)
      # @option options [Object] :unused Currently no options are used
      # @return [Rational] The converted rational number
      # @raise [CoercionError] If the value cannot be converted to a rational number
      # @example Convert numeric strings to rational numbers
      #   call("3/4")     # => (3/4)
      #   call("2.5")     # => (5/2)
      #   call("0")       # => (0/1)
      # @example Convert numeric types to rational numbers
      #   call(3.14)      # => (157/50)
      #   call(2)         # => (2/1)
      #   call(0.5)       # => (1/2)
      # @example Handle edge cases
      #   call("")        # => (0/1)
      #   call(nil)       # => (0/1)
      #   call(0)         # => (0/1)
      def call(value, options = {})
        Rational(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError, ZeroDivisionError
        type = Locale.t("cmdx.types.rational")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to BigDecimal format
    #
    # Handles conversion from numeric strings, integers, floats, and other
    # values that can be converted to BigDecimal using Ruby's BigDecimal() method.
    module BigDecimal

      extend self

      DEFAULT_PRECISION = 14

      # Converts a value to a BigDecimal
      #
      # @param value [Object] The value to convert to BigDecimal
      # @param options [Hash] Optional configuration parameters
      # @option options [Integer] :precision The precision to use (defaults to DEFAULT_PRECISION)
      # @return [BigDecimal] The converted BigDecimal value
      # @raise [CoercionError] If the value cannot be converted to BigDecimal
      # @example Convert numeric strings to BigDecimal
      #   call("123.45")                   # => #<BigDecimal:7f8b8c0d8e0f '0.12345E3',9(18)>
      #   call("0.001", precision: 6)      # => #<BigDecimal:7f8b8c0d8e0f '0.1E-2',9(18)>
      # @example Convert other numeric types
      #   call(42)                         # => #<BigDecimal:7f8b8c0d8e0f '0.42E2',9(18)>
      #   call(3.14159)                    # => #<BigDecimal:7f8b8c0d8e0f '0.314159E1',9(18)>
      def call(value, options = {})
        BigDecimal(value, options[:precision] || DEFAULT_PRECISION)
      rescue ArgumentError, TypeError
        type = Locale.t("cmdx.types.big_decimal")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

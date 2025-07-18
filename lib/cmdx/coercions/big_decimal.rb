# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to BigDecimal.
    #
    # This coercion handles conversion of various types to BigDecimal with
    # configurable precision. It provides precise decimal arithmetic capabilities
    # for financial calculations and other use cases requiring exact decimal representation.
    class BigDecimal < Coercion

      DEFAULT_PRECISION = 14

      # Converts the given value to a BigDecimal.
      #
      # @param value [Object] the value to convert to a BigDecimal
      # @param options [Hash] optional configuration
      # @option options [Integer] :precision the precision for the BigDecimal (defaults to 14)
      #
      # @return [BigDecimal] the converted BigDecimal value
      #
      # @raise [CoercionError] if the value cannot be converted to a BigDecimal
      #
      # @example Converting a string
      #   Coercions::BigDecimal.call('123.45') #=> #<BigDecimal:...,'0.12345E3',18(27)>
      #
      # @example Converting with custom precision
      #   Coercions::BigDecimal.call('123.456789', precision: 10) #=> #<BigDecimal:...,'0.123456789E3',18(27)>
      #
      # @example Converting an integer
      #   Coercions::BigDecimal.call(100) #=> #<BigDecimal:...,'0.1E3',9(18)>
      def call(value, options = {})
        BigDecimal(value, options[:precision] || DEFAULT_PRECISION)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "big decimal",
          default: "could not coerce into a big decimal"
        )
      end

    end
  end
end

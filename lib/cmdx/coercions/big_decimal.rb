# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to BigDecimal type.
    #
    # The BigDecimal coercion converts parameter values to BigDecimal objects
    # for high-precision decimal arithmetic. Supports configurable precision
    # and handles various numeric input formats.
    #
    # @example Basic BigDecimal coercion
    #   class ProcessOrderTask < CMDx::Task
    #     required :total_amount, type: :big_decimal
    #     optional :tax_rate, type: :big_decimal, precision: 4
    #   end
    #
    # @example Coercion behavior
    #   Coercions::BigDecimal.call("123.45")          # => #<BigDecimal:...,'0.12345E3',18(27)>
    #   Coercions::BigDecimal.call(42)                # => #<BigDecimal:...,'0.42E2',9(18)>
    #   Coercions::BigDecimal.call("0.333333", precision: 6)  # Custom precision
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    module BigDecimal

      # Default precision for BigDecimal calculations
      # @return [Integer] default precision value
      DEFAULT_PRECISION = 14

      module_function

      # Coerce a value to BigDecimal.
      #
      # @param value [Object] value to coerce to BigDecimal
      # @param options [Hash] coercion options
      # @option options [Integer] :precision decimal precision (default: 14)
      # @return [BigDecimal] coerced BigDecimal value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::BigDecimal.call("123.45")                    # => BigDecimal with default precision
      #   Coercions::BigDecimal.call("0.333", precision: 10)      # => BigDecimal with custom precision
      #   Coercions::BigDecimal.call(42.5)                        # => BigDecimal from float
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

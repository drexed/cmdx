# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Complex number format
    #
    # Handles conversion from numeric strings, integers, floats, and other
    # values that can be converted to Complex using Ruby's Complex() method.
    module Complex

      extend self

      # Converts a value to a Complex number
      #
      # @param value [Object] The value to convert to Complex
      # @param options [Hash] Optional configuration parameters (currently unused)
      #
      # @return [Complex] The converted Complex number value
      #
      # @raise [CoercionError] If the value cannot be converted to Complex
      #
      # @example Convert numeric strings to Complex
      #   Complex.call("3+4i")                     # => (3+4i)
      #   Complex.call("2.5")                      # => (2.5+0i)
      # @example Convert other numeric types
      #   Complex.call(5)                          # => (5+0i)
      #   Complex.call(3.14)                       # => (3.14+0i)
      #   Complex.call(Complex(1, 2))              # => (1+2i)
      def call(value, options = {})
        Complex(value)
      rescue ArgumentError, TypeError
        type = Locale.t("cmdx.types.complex")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Rational type.
    #
    # The Rational coercion converts parameter values to Rational number objects
    # using Ruby's built-in Rational() method, with proper error handling
    # for values that cannot be converted to rational numbers.
    #
    # @example Basic rational coercion
    #   class MathTask < CMDx::Task
    #     required :fraction, type: :rational
    #     optional :ratio, type: :rational, default: Rational(1, 2)
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Rational.call("1/2")      # => (1/2)
    #   Coercions::Rational.call("3/4")      # => (3/4)
    #   Coercions::Rational.call(0.5)        # => (1/2)
    #   Coercions::Rational.call("invalid")  # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    module Rational

      module_function

      # Coerce a value to Rational.
      #
      # @param value [Object] value to coerce to rational number
      # @param _options [Hash] coercion options (unused)
      # @return [Rational] coerced rational number value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::Rational.call("1/2")    # => (1/2)
      #   Coercions::Rational.call(0.75)     # => (3/4)
      #   Coercions::Rational.call("3.5")    # => (7/2)
      def call(value, _options = {})
        Rational(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "rational",
          default: "could not coerce into a rational"
        )
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Symbol type using Ruby's to_sym method.
    #
    # This coercion handles various input types by converting them to symbols.
    # It provides error handling for values that cannot be converted to symbols
    # and raises appropriate CMDx coercion errors with localized messages.
    module Symbol

      extend self

      # Coerces a value to Symbol type.
      #
      # @param value [Object] The value to coerce to a symbol
      # @param options [Hash] Optional configuration parameters (unused in this coercion)
      # @return [Symbol] The coerced symbol value
      # @raise [CoercionError] If the value cannot be converted to a symbol
      # @example Basic symbol coercion
      #   call("hello")           # => :hello
      #   call("user_id")         # => :user_id
      #   call("")                # => :""
      #   call(:existing)         # => :existing
      def call(value, options = {})
        value.to_sym
      rescue NoMethodError
        type = Locale.t("cmdx.types.symbol")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to String type using Ruby's built-in String() method.
    #
    # This coercion handles various input types by converting them to their
    # string representation. It's a simple wrapper around Ruby's String()
    # method for consistency with the CMDx coercion interface.
    module String

      extend self

      # Coerces a value to String type.
      #
      # @param value [Object] The value to coerce to a string
      # @param options [Hash] Optional configuration parameters (unused in this coercion)
      # @option options [Object] :* Any configuration option (unused)
      #
      # @return [String] The coerced string value
      #
      # @raise [TypeError] If the value cannot be converted to a string
      #
      # @example Basic string coercion
      #   String.call("hello")           # => "hello"
      #   String.call(42)                # => "42"
      #   String.call([1, 2, 3])         # => "[1, 2, 3]"
      #   String.call(nil)               # => ""
      #   String.call(true)              # => "true"
      #
      # @rbs (untyped value, ?Hash[Symbol, untyped] options) -> String
      def call(value, options = {})
        String(value)
      end

    end
  end
end

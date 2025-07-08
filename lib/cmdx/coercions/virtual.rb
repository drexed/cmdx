# frozen_string_literal: true

module CMDx
  module Coercions
    # Virtual coercion that returns values unchanged.
    #
    # The Virtual coercion is a pass-through that returns the input value
    # without any transformation. This is useful for parameters that should
    # not undergo type coercion or when you want to preserve the original
    # value type and structure.
    #
    # @example Virtual coercion usage
    #   class ProcessOrderTask < CMDx::Task
    #     required :order  # defaults to virtual type
    #     optional :metadata, type: :virtual
    #     optional :config, type: :virtual
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Virtual.call("string")     # => "string"
    #   Coercions::Virtual.call(123)          # => 123
    #   Coercions::Virtual.call([1, 2, 3])    # => [1, 2, 3]
    #   Coercions::Virtual.call({a: 1})       # => {a: 1}
    #   Coercions::Virtual.call(nil)          # => nil
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions (defaults to virtual)
    class Virtual < Coercion

      # Return the value unchanged (no coercion).
      #
      # @param value [Object] value to pass through unchanged
      # @param _options [Hash] coercion options (unused)
      # @return [Object] the original value without modification
      #
      # @example
      #   Coercions::Virtual.call(anything)  # => anything
      def call(value, _options = {})
        value
      end

    end
  end
end

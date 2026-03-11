# frozen_string_literal: true

module CMDx
  module Utils
    # Provides array wrapping utilities for normalizing input values
    # into consistent array structures.
    module Wrap

      extend self

      # Wraps an object in an array if it is not already an array.
      #
      # @param object [Object] The object to wrap in an array
      #
      # @return [Array] The wrapped array
      #
      # @example Already an array
      #   Wrap.array([1, 2, 3])
      #   # => [1, 2, 3]
      # @example Single value
      #   Wrap.array(1)
      #   # => [1]
      # @example Nil value
      #   Wrap.array(nil)
      #   # => []
      #
      # @rbs (untyped object) -> Array[untyped]
      def array(object)
        return object if object.is_a?(Array)

        Array(object)
      end

    end
  end
end

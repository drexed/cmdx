# frozen_string_literal: true

module CMDx
  module Utils
    # Wraps values into arrays.
    module Wrap

      # Ensures a value is wrapped in an array.
      #
      # @param value [Object] the value to wrap
      #
      # @return [Array]
      #
      # @rbs (untyped value) -> Array[untyped]
      def self.call(value)
        case value
        when nil then []
        when Array then value
        else [value]
        end
      end

    end
  end
end

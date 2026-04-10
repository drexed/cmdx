# frozen_string_literal: true

module CMDx
  module Coercions
    module String

      # @rbs (untyped value) -> String
      def self.call(value)
        return value if value.is_a?(::String)

        value.to_s
      end

    end
  end
end

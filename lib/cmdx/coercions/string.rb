# frozen_string_literal: true

module CMDx
  module Coercions
    module String

      extend self

      def call(value, options = {})
        String(value)
      end

    end
  end
end

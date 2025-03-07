# frozen_string_literal: true

module CMDx
  module Coercions
    module String

      module_function

      def call(value, _options = {})
        String(value)
      end

    end
  end
end

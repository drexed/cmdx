# frozen_string_literal: true

module CMDx
  module Coercions
    module Array

      module_function

      def call(value, _options = {})
        if value.is_a?(::String) && value.start_with?("[")
          JSON.parse(value)
        else
          Array(value)
        end
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    module Array

      module_function

      def call(value, _options = {})
        Array(value)
      end

    end
  end
end

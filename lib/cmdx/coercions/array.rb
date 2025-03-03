# frozen_string_literal: true

module CMDx
  module Coercions
    module Array

      module_function

      def call(v, _options = {})
        Array(v)
      end

    end
  end
end

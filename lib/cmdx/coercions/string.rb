# frozen_string_literal: true

module CMDx
  module Coercions
    module String

      module_function

      def call(v, _options = {})
        String(v)
      end

    end
  end
end

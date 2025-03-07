# frozen_string_literal: true

module CMDx
  module Coercions
    module Virtual

      module_function

      def call(value, _options = {})
        value
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    module Virtual

      module_function

      def call(v, _options = {})
        v
      end

    end
  end
end

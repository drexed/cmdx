# frozen_string_literal: true

module CMDx
  module Coercions
    module String

      module_function

      def call(value, options = {}) # rubocop:disable Lint/UnusedMethodArgument
        String(value)
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Utils
    module Call

      module_function

      def call(target, ...)
        return target unless target.respond_to?(:call)

        target.call(...)
      end

    end
  end
end

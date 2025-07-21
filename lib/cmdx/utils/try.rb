# frozen_string_literal: true

module CMDx
  module Utils
    module Try

      module_function

      def call(target, signature, ...)
        if signature.is_a?(Proc)
          signature.call(target, ...)
        elsif target.respond_to?(signature, true)
          target.send(signature, ...)
        elsif target.is_a?(Hash)
          target[signature]
        end
      end

    end
  end
end

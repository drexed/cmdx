# frozen_string_literal: true

module CMDx
  module Utils
    module MethodName

      ROOTFIX = proc do |o, &block|
        o == true ? block.call : o
      end.freeze

      module_function

      def call(method_name, source, options = {})
        options[:as] || begin
          prefix = ROOTFIX.call(options[:prefix]) { "#{source}_" }
          suffix = ROOTFIX.call(options[:suffix]) { "_#{source}" }

          "#{prefix}#{method_name}#{suffix}".strip.to_sym
        end
      end

    end
  end
end

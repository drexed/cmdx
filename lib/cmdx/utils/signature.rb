# frozen_string_literal: true

module CMDx
  module Utils
    module Signature

      AFFIXER = proc do |value, &block|
        value.is_a?(TrueClass) ? block.call : value
      end.freeze

      module_function

      def call(target, method, options = {})
        options[:as] || begin
          prefix = AFFIXER.call(options[:prefix]) { "#{target}_" }
          suffix = AFFIXER.call(options[:suffix]) { "_#{target}" }

          "#{prefix}#{method}#{suffix}".strip.to_sym
        end
      end

    end
  end
end

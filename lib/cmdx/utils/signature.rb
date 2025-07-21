# frozen_string_literal: true

module CMDx
  module Utils
    module Signature

      SIGNATURE = proc do |value, &block|
        # Affix target name if true
        value.is_a?(TrueClass) ? block.call : value
      end.freeze

      module_function

      def call(target, method, options = {})
        options[:as] || begin
          prefix = SIGNATURE.call(options[:prefix]) { "#{target}_" }
          suffix = SIGNATURE.call(options[:suffix]) { "_#{target}" }

          "#{prefix}#{method}#{suffix}".strip.to_sym
        end
      end

    end
  end
end

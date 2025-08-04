# frozen_string_literal: true

module CMDx
  module Utils
    module Inspect

      extend self

      FORMATTER = proc do |key, value|
        "#{key}=#{value.inspect}"
      end.freeze
      private_constant :FORMATTER

      def stringify(hash, &block)
        block ||= FORMATTER
        hash.map(&block).join(" ")
      end

    end
  end
end

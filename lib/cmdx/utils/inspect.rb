# frozen_string_literal: true

module CMDx
  module Utils
    module Inspect

      extend self

      DEFAULT_PRINTER = proc { |key, value| "#{key}=#{value.inspect}" }.freeze

      def dump(hash, &block)
        block ||= DEFAULT_PRINTER
        hash.map(&block).join(" ")
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Utils
    module Normalize

      # Normalizes input args by merging positional hash and keyword args.
      #
      # @param input [Hash]
      # @param kwargs [Hash]
      # @return [Hash{Symbol => Object}]
      #
      # @rbs (Hash[untyped, untyped] input, Hash[Symbol, untyped] kwargs) -> Hash[Symbol, untyped]
      def self.args(input, kwargs)
        merged = input.merge(kwargs)
        merged.transform_keys(&:to_sym)
      end

    end
  end
end

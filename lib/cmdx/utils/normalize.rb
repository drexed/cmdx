# frozen_string_literal: true

module CMDx
  module Utils
    # Normalizes input values for attribute processing.
    module Normalize

      # Normalizes a value to nil when it is blank (empty string or nil).
      #
      # @param value [Object]
      #
      # @return [Object, nil]
      #
      # @rbs (untyped value) -> untyped
      def self.blank_to_nil(value)
        return nil if value.nil?
        return nil if value.respond_to?(:empty?) && value.empty?

        value
      end

      # Extracts a nested value using a dot-separated path.
      #
      # @param source [Hash] the source data
      # @param path [String] dot-separated path
      #
      # @return [Object, nil]
      #
      # @rbs (Hash[untyped, untyped] source, String path) -> untyped
      def self.dig(source, path)
        keys = path.split(".")
        keys.reduce(source) do |obj, key|
          break nil unless obj.respond_to?(:[])

          obj[key.to_sym] || obj[key]
        end
      end

    end
  end
end

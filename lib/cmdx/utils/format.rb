# frozen_string_literal: true

module CMDx
  module Utils
    # Formatting helpers used for inspect strings and display.
    module Format

      EMPTY_HASH = {}.freeze
      EMPTY_ARRAY = [].freeze
      EMPTY_STRING = ""

      # Converts a hash to a readable string.
      #
      # @param hash [Hash] the data to format
      #
      # @return [String]
      #
      # @rbs (Hash[untyped, untyped] hash) -> String
      def self.to_str(hash)
        hash.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      end

      # Converts a class name to a formatted task type.
      #
      # @param klass [Class, String] the class to format
      #
      # @return [String]
      #
      # @rbs (untyped klass) -> String
      def self.type_name(klass)
        name = klass.is_a?(String) ? klass : klass.name
        return "anonymous" if name.nil?

        name.gsub("::", ".").downcase
      end

      # @rbs (untyped value) -> String
      def self.truncate(value, max: 100)
        str = value.to_s
        str.length > max ? "#{str[0, max]}..." : str
      end

    end
  end
end

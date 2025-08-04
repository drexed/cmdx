# frozen_string_literal: true

module CMDx
  module Utils
    module Format

      extend self

      RAW_FORMATTER = proc do |key, value|
        "#{key}=#{value}"
      end.freeze
      private_constant :RAW_FORMATTER
      STR_FORMATTER = proc do |key, value|
        "#{key}=#{value.inspect}"
      end.freeze
      private_constant :STR_FORMATTER

      def to_log(message)
        if message.is_a?(Hash)
          message
        elsif message.respond_to?(:to_hash)
          message.to_hash
        elsif message.respond_to?(:to_h)
          message.to_h
        else
          { message: message }
        end
      end

      def to_raw(hash, &block)
        block ||= RAW_FORMATTER
        hash.map(&block).join(" ")
      end

      def to_str(hash, &block)
        block ||= STR_FORMATTER
        hash.map(&block).join(" ")
      end

    end
  end
end

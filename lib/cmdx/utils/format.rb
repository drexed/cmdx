# frozen_string_literal: true

module CMDx
  module Utils
    module Format

      extend self

      FORMATTER = proc do |key, value|
        "#{key}=#{value.inspect}"
      end.freeze
      private_constant :FORMATTER

      def to_log(message)
        if message.respond_to?(:to_hash)
          message.to_hash
        elsif message.respond_to?(:to_h)
          message.to_h
        else
          { message: message }
        end
      end

      def to_str(hash, &block)
        block ||= FORMATTER
        hash.map(&block).join(" ")
      end

    end
  end
end

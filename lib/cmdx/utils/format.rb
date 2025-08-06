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
        if message.respond_to?(:to_h) && message.class.ancestors.any? { |a| a.to_s.start_with?("CMDx") }
          message.to_h
        else
          message
        end
      end

      def to_str(hash, &block)
        block ||= FORMATTER
        hash.map(&block).join(" ")
      end

    end
  end
end

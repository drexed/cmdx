# frozen_string_literal: true

module CMDx
  module Utils
    module Format

      extend self

      FORMATTER = proc do |key, value|
        "#{key}=#{value.inspect}"
      end.freeze
      private_constant :FORMATTER

      def logify(message)
        hash =
          if message.respond_to?(:to_hash)
            message.to_hash
          elsif message.respond_to?(:to_h)
            message.to_h
          else
            { message: message }
          end

        # TODO: remove this if not using ansi colors
        # if options.delete(:ansi_colorize) && message.is_a?(Result)
        #   COLORED_KEYS.each { |k| m[k] = ResultAnsi.call(m[k]) if m.key?(k) }
        # elsif !message.is_a?(Result)
        #   m.merge!(TaskSerializer.call(task), message: message)
        # end

        hash[:origin] ||= "CMDx"
        hash
      end

      def stringify(hash, &block)
        block ||= FORMATTER
        hash.map(&block).join(" ")
      end

    end
  end
end

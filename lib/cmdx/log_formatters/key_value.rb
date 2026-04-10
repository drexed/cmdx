# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Key=value pairs formatter for log parsing tools.
    class KeyValue

      # @param data [Hash] structured log data
      # @return [String]
      def call(data)
        data.map { |k, v| "#{k}=#{format_value(v)}" }.join(" ")
      end

      private

      def format_value(value)
        case value
        when String then "\"#{value}\""
        when Hash   then "\"{#{value.map { |k, v| "#{k}: #{v}" }.join(', ')}}\""
        when Array  then "\"[#{value.join(', ')}]\""
        when nil    then "nil"
        else value.to_s
        end
      end

    end
  end
end

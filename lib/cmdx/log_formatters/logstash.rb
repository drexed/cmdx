# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Logstash-compatible JSON formatter with @version and @timestamp.
    class Logstash

      # @param data [Hash] structured log data
      # @return [String]
      def call(data)
        entry = {
          "@version" => "1",
          "@timestamp" => Time.now.utc.iso8601(6),
          "progname" => "cmdx",
          "message" => deep_serialize(data)
        }
        JSON.generate(entry)
      end

      private

      def deep_serialize(obj)
        case obj
        when Hash        then obj.transform_keys(&:to_s).transform_values { |v| deep_serialize(v) }
        when Array       then obj.map { |v| deep_serialize(v) }
        when ::Exception then "#{obj.class}: #{obj.message}"
        when Symbol      then obj.to_s
        else obj
        end
      end

    end
  end
end

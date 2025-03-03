# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      def call(_severity, time, _progname, message)
        if message.is_a?(Hash)
          message["@version"]   ||= "1"
          message["@timestamp"] ||= time.utc.iso8601(3)
        end

        JSON.dump(message)
      end

    end
  end
end

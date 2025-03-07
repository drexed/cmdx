# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      def call(_severity, time, _progname, message)
        if message.is_a?(Hash)
          message["@version"]   ||= "1"
          message["@timestamp"] ||= Utils::DatetimeFormatter.call(time.utc)
        end

        JSON.dump(message)
      end

    end
  end
end

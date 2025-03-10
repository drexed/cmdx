# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      def call(_severity, time, _progname, message)
        message = message.to_h if message.is_a?(Result)

        if message.is_a?(Hash)
          message["@version"]   ||= "1"
          message["@timestamp"] ||= Utils::DatetimeFormatter.call(time.utc)
        end

        message = JSON.dump(message)
        message << "\n"
      end

    end
  end
end

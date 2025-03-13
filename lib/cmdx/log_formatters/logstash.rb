# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message).merge!(
          severity:,
          pid: Process.pid,
          "@version" => "1",
          "@timestamp" => Utils::LogTimestamp.call(time.utc)
        )

        JSON.dump(m) << "\n"
      end

    end
  end
end

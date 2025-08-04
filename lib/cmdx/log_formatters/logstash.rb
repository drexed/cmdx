# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      def call(severity, time, progname, message)
        hash = data(severity, time, progname, message)

        ::JSON.dump(hash) << "\n"
      end

      def data(severity, time, progname, message)
        Utils::Format.to_log(message).merge!(
          severity:,
          progname:,
          pid: Process.pid,
          "@version" => "1",
          "@timestamp" => time.utc.iso8601(6)
        )
      end

    end
  end
end

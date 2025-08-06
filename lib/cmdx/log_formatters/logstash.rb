# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      def call(severity, time, progname, message)
        hash = {
          "@version" => "1",
          "@timestamp" => time.utc.iso8601(6),
          severity:,
          progname:,
          pid: Process.pid,
          message: Utils::Format.to_log(message)
        }

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

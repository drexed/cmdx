# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      def call(severity, time, progname, message)
        hash = Utils::Format.to_log(message).merge!(
          severity:,
          progname:,
          pid: Process.pid,
          "@version" => "1",
          "@timestamp" => time.utc.iso8601(6)
        )

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

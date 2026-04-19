# frozen_string_literal: true

module CMDx
  module LogFormatters
    # `Logger` formatter that produces one JSON line per entry in the shape
    # expected by Logstash (`@version` + `@timestamp`).
    class Logstash

      # @param severity [String] Logger severity name
      # @param time [Time]
      # @param progname [String, nil]
      # @param message [Object]
      # @return [String] JSON line terminated by `"\n"`
      def call(severity, time, progname, message)
        hash = {
          severity:,
          progname:,
          pid: Process.pid,
          message: message.respond_to?(:to_h) ? message.to_h : message,
          "@version" => "1",
          "@timestamp" => time.utc.iso8601(6)
        }

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    # `Logger` formatter that produces one JSON line per entry in the shape
    # expected by Logstash (`@version` + `@timestamp`). Falls back to
    # `message.inspect` if `JSON.dump` raises (e.g. cyclic / non-encodable
    # payload) so logging never crashes the caller.
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
      rescue StandardError => e
        hash[:message] = message.inspect
        hash[:logerr]  = Util.to_error_s(e)
        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

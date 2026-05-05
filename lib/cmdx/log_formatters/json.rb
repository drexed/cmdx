# frozen_string_literal: true

module CMDx
  module LogFormatters
    # `Logger` formatter that emits one JSON object per line with `severity`,
    # ISO8601 `timestamp`, `progname`, `pid`, and `message` (rendered via
    # `#to_h` when available — Result instances serialize themselves).
    class JSON

      # @param severity [String] Logger severity name
      # @param time [Time]
      # @param progname [String, nil]
      # @param message [Object] anything `Logger` was handed
      # @return [String] JSON line terminated by `"\n"`
      def call(severity, time, progname, message)
        hash = {
          severity:,
          timestamp: time.utc.iso8601(6),
          progname:,
          pid: Process.pid,
          message: message.respond_to?(:to_h) ? message.to_h : message
        }

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

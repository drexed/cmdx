# frozen_string_literal: true

module CMDx
  module LogFormatters
    # `Logger` formatter that emits `key=value.inspect` pairs on a single
    # line. Hash-like messages (including Result) are flattened into the
    # top-level `message` field via `#to_h`.
    class KeyValue

      # @param severity [String] Logger severity name
      # @param time [Time]
      # @param progname [String, nil]
      # @param message [Object]
      # @return [String] single-line key=value line terminated by `"\n"`
      def call(severity, time, progname, message)
        hash = {
          severity:,
          timestamp: time.utc.iso8601(6),
          progname:,
          pid: Process.pid,
          message: message.respond_to?(:to_h) ? message.to_h : message
        }

        hash.map { |k, v| "#{k}=#{v.inspect}" }.join(" ") << "\n"
      end

    end
  end
end

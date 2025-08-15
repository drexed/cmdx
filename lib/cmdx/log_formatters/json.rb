# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Formats log messages as JSON for structured logging
    #
    # This formatter converts log entries into JSON format with standardized fields
    # including severity, timestamp, program name, process ID, and formatted message.
    # The output is suitable for log aggregation systems and structured analysis.
    class JSON

      # Formats a log entry as a JSON string
      #
      # @param severity [String] The log level (e.g., "INFO", "ERROR", "DEBUG")
      # @param time [Time] The timestamp when the log entry was created
      # @param progname [String, nil] The program name or identifier
      # @param message [Object] The log message content
      #
      # @return [String] A JSON-formatted log entry with a trailing newline
      #
      # @example Basic usage
      #   JSON.new.call("INFO", Time.now, "MyApp", "User logged in")
      #   # => '{"severity":"INFO","timestamp":"2024-01-15T10:30:45.123456Z","progname":"MyApp","pid":12345,"message":"User logged in"}\n'
      def call(severity, time, progname, message)
        hash = {
          severity:,
          timestamp: time.utc.iso8601(6),
          progname:,
          pid: Process.pid,
          message: Utils::Format.to_log(message)
        }

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

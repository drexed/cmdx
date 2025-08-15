# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Formats log messages as key-value pairs for structured logging
    #
    # This formatter converts log entries into key-value format with standardized fields
    # including severity, timestamp, program name, process ID, and formatted message.
    # The output is suitable for log parsing tools and human-readable structured logs.
    class KeyValue

      # Formats a log entry as a key-value string
      #
      # @param severity [String] The log level (e.g., "INFO", "ERROR", "DEBUG")
      # @param time [Time] The timestamp when the log entry was created
      # @param progname [String, nil] The program name or identifier
      # @param message [Object] The log message content
      #
      # @return [String] A key-value formatted log entry with a trailing newline
      #
      # @example Basic usage
      #   call("INFO", Time.now, "MyApp", "User logged in")
      #   # => "severity=INFO timestamp=2024-01-15T10:30:45.123456Z progname=MyApp pid=12345 message=User logged in\n"
      def call(severity, time, progname, message)
        hash = {
          severity:,
          timestamp: time.utc.iso8601(6),
          progname:,
          pid: Process.pid,
          message: Utils::Format.to_log(message)
        }

        Utils::Format.to_str(hash) << "\n"
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Formats log messages as single-line text for human-readable logging
    #
    # This formatter converts log entries into a compact single-line format with
    # severity abbreviation, ISO8601 timestamp, process ID, and formatted message.
    # The output is optimized for human readability and traditional log file formats.
    class Line

      # Formats a log entry as a single-line string
      #
      # @param severity [String] The log level (e.g., "INFO", "ERROR", "DEBUG")
      # @param time [Time] The timestamp when the log entry was created
      # @param progname [String, nil] The program name or identifier
      # @param message [Object] The log message content
      #
      # @return [String] A single-line formatted log entry with a trailing newline
      #
      # @example Basic usage
      #   call("INFO", Time.now, "MyApp", "User logged in")
      #   # => "I, [2024-01-15T10:30:45.123456Z #12345] INFO -- MyApp: User logged in\n"
      def call(severity, time, progname, message)
        "#{severity[0]}, [#{time.utc.iso8601(6)} ##{Process.pid}] #{severity} -- #{progname}: #{message}\n"
      end

    end
  end
end

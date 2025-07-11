# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Pretty key-value log formatter that outputs structured log entries as human-readable key=value pairs.
    #
    # This formatter converts log entries into a space-separated key=value format with ANSI coloring
    # for enhanced readability in terminal output. Each log entry includes metadata such as severity,
    # process ID, and timestamp, with each entry terminated by a newline character.
    class PrettyKeyValue

      # Formats a log entry as a colorized key=value string.
      #
      # @param severity [String] the log severity level (e.g., "INFO", "ERROR")
      # @param time [Time] the timestamp when the log entry was created
      # @param task [Object] the task object associated with the log entry
      # @param message [String] the log message content
      #
      # @return [String] the formatted key=value log entry with ANSI colors and trailing newline
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::PrettyKeyValue.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   # => "severity=INFO pid=12345 timestamp=2024-01-01T12:00:00Z message=Task completed\n"
      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message, ansi_colorize: true).merge!(
          severity:,
          pid: Process.pid,
          timestamp: Utils::LogTimestamp.call(time.utc)
        )

        m = m.map { |k, v| "#{k}=#{v}" }.join(" ") if m.is_a?(Hash)
        m << "\n"
      end

    end
  end
end

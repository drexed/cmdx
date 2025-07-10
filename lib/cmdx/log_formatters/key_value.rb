# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Key-value log formatter that outputs structured log entries as key=value pairs.
    #
    # This formatter converts log entries into key-value format, including metadata
    # such as severity, process ID, and timestamp. Each log entry is output as
    # space-separated key=value pairs followed by a newline character.
    #
    # @since 1.0.0
    class KeyValue

      # Formats a log entry as a key=value string.
      #
      # @param severity [String] the log severity level (e.g., "INFO", "ERROR")
      # @param time [Time] the timestamp when the log entry was created
      # @param task [Object] the task object associated with the log entry
      # @param message [String] the log message content
      #
      # @return [String] the formatted key=value log entry with trailing newline
      #
      # @raise [StandardError] if the log data cannot be serialized to key=value format
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::KeyValue.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   # => "severity=INFO pid=12345 timestamp=2024-01-01T12:00:00Z message=Task completed\n"
      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message).merge!(
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

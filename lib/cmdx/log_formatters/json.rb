# frozen_string_literal: true

module CMDx
  module LogFormatters
    # JSON log formatter that outputs structured log entries as JSON.
    #
    # This formatter converts log entries into JSON format, including metadata
    # such as severity, process ID, and timestamp. Each log entry is output as
    # a single line of JSON followed by a newline character.
    #
    # @since 1.0.0
    class Json

      # Formats a log entry as a JSON string.
      #
      # @param severity [String] the log severity level (e.g., "INFO", "ERROR")
      # @param time [Time] the timestamp when the log entry was created
      # @param task [Object] the task object associated with the log entry
      # @param message [String] the log message content
      #
      # @return [String] the formatted JSON log entry with trailing newline
      #
      # @raise [JSON::GeneratorError] if the log data cannot be serialized to JSON
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::Json.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   # => "{\"severity\":\"INFO\",\"pid\":12345,\"timestamp\":\"2024-01-01T12:00:00Z\",\"message\":\"Task completed\"}\n"
      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message).merge!(
          severity:,
          pid: Process.pid,
          timestamp: Utils::LogTimestamp.call(time.utc)
        )

        JSON.dump(m) << "\n"
      end

    end
  end
end

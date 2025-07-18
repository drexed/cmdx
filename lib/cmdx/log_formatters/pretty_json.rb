# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Pretty JSON log formatter that outputs structured log entries as formatted JSON.
    #
    # This formatter converts log entries into pretty-printed JSON format with proper
    # indentation and line breaks, including metadata such as severity, process ID,
    # and timestamp. Each log entry is output as a multi-line JSON structure followed
    # by a newline character, making it human-readable while maintaining structure.
    class PrettyJson

      # Formats a log entry as a pretty-printed JSON string.
      #
      # @param severity [String] the log severity level (e.g., "INFO", "ERROR")
      # @param time [Time] the timestamp when the log entry was created
      # @param task [Object] the task object associated with the log entry
      # @param message [String] the log message content
      #
      # @return [String] the formatted pretty JSON log entry with trailing newline
      #
      # @raise [JSON::GeneratorError] if the log data cannot be serialized to JSON
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::PrettyJson.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   # => "{\n  \"severity\": \"INFO\",\n  \"pid\": 12345,\n  \"timestamp\": \"2024-01-01T12:00:00Z\",\n  \"message\": \"Task completed\"\n}\n"
      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message).merge!(
          severity:,
          pid: Process.pid,
          timestamp: Utils::LogTimestamp.call(time.utc)
        )

        JSON.pretty_generate(m) << "\n"
      end

    end
  end
end

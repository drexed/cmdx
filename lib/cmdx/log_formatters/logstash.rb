# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Logstash log formatter that outputs structured log entries in Logstash JSON format.
    #
    # This formatter converts log entries into Logstash-compatible JSON format, including
    # required Logstash fields such as @version and @timestamp, along with metadata
    # such as severity and process ID. Each log entry is output as a single line of
    # JSON followed by a newline character.
    class Logstash

      # Formats a log entry as a Logstash-compatible JSON string.
      #
      # @param severity [String] the log severity level (e.g., "INFO", "ERROR")
      # @param time [Time] the timestamp when the log entry was created
      # @param task [Object] the task object associated with the log entry
      # @param message [String] the log message content
      #
      # @return [String] the formatted Logstash JSON log entry with trailing newline
      #
      # @raise [JSON::GeneratorError] if the log data cannot be serialized to JSON
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::Logstash.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   # => "{\"severity\":\"INFO\",\"pid\":12345,\"@version\":\"1\",\"@timestamp\":\"2024-01-01T12:00:00.000Z\",\"message\":\"Task completed\"}\n"
      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message).merge!(
          severity:,
          pid: Process.pid,
          "@version" => "1",
          "@timestamp" => Utils::LogTimestamp.call(time.utc)
        )

        JSON.dump(m) << "\n"
      end

    end
  end
end

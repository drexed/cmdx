# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Formats log messages as Logstash-compatible JSON for structured logging
    #
    # This formatter converts log entries into Logstash-compatible JSON format with
    # standardized fields including @version, @timestamp, severity, program name,
    # process ID, and formatted message. The output follows Logstash event format
    # specifications for seamless integration with ELK stack and similar systems.
    class Logstash

      # Formats a log entry as a Logstash-compatible JSON string
      #
      # @param severity [String] The log level (e.g., "INFO", "ERROR", "DEBUG")
      # @param time [Time] The timestamp when the log entry was created
      # @param progname [String, nil] The program name or identifier
      # @param message [Object] The log message content
      #
      # @return [String] A Logstash-compatible JSON-formatted log entry with a trailing newline
      #
      # @example Basic usage
      #   Logstash.new.call("INFO", Time.now, "MyApp", "User logged in")
      #   # => '{"@version":"1","@timestamp":"2024-01-15T10:30:45.123456Z","severity":"INFO","progname":"MyApp","pid":12345,"message":"User logged in"}\n'
      def call(severity, time, progname, message)
        hash = {
          "@version" => "1",
          "@timestamp" => time.utc.iso8601(6),
          severity:,
          progname:,
          pid: Process.pid,
          message: Utils::Format.to_log(message)
        }

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

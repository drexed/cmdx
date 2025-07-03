# frozen_string_literal: true

module CMDx
  module Utils
    # Utility for formatting timestamps in CMDx log entries.
    #
    # LogTimestamp provides consistent timestamp formatting across all CMDx
    # log formatters, ensuring uniform time representation in logs regardless
    # of the chosen output format. Uses ISO 8601 format with microsecond precision.
    #
    # @example Basic timestamp formatting
    #   Utils::LogTimestamp.call(Time.now)
    #   # => "2022-07-17T18:43:15.123456"
    #
    # @example Usage in log formatters
    #   timestamp = Utils::LogTimestamp.call(time.utc)
    #   log_entry = "#{severity} [#{timestamp}] #{message}"
    #
    # @example Consistent formatting across formatters
    #   # JSON formatter
    #   { "timestamp": Utils::LogTimestamp.call(time.utc) }
    #
    #   # Line formatter
    #   "[#{Utils::LogTimestamp.call(time.utc)} ##{Process.pid}]"
    #
    # @see CMDx::LogFormatters::Json Uses this for JSON timestamp field
    # @see CMDx::LogFormatters::Line Uses this for traditional log format
    # @see CMDx::LogFormatters::Logstash Uses this for @timestamp field
    module LogTimestamp

      # ISO 8601 datetime format with microsecond precision
      # @return [String] strftime format string for consistent timestamp formatting
      DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N"

      module_function

      # Formats a Time object as an ISO 8601 timestamp string.
      #
      # Converts the given time to a standardized string representation
      # using ISO 8601 format with microsecond precision. This ensures
      # consistent timestamp formatting across all CMDx log outputs.
      #
      # @param time [Time] Time object to format
      # @return [String] ISO 8601 formatted timestamp with microseconds
      #
      # @example Current time formatting
      #   LogTimestamp.call(Time.now)
      #   # => "2022-07-17T18:43:15.123456"
      #
      # @example UTC time formatting for logs
      #   LogTimestamp.call(Time.now.utc)
      #   # => "2022-07-17T18:43:15.123456"
      #
      # @example Integration with log formatters
      #   def format_log_entry(severity, time, message)
      #     timestamp = LogTimestamp.call(time.utc)
      #     "#{severity} [#{timestamp}] #{message}"
      #   end
      def call(time)
        time.strftime(DATETIME_FORMAT)
      end

    end
  end
end

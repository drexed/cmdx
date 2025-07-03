# frozen_string_literal: true

module CMDx
  module LogFormatters
    # JSON log formatter for CMDx logging system.
    #
    # Formats log entries as single-line JSON objects containing task execution metadata
    # including severity, timestamp, process ID, and serialized task information.
    # Ideal for structured logging systems that need to parse log data programmatically.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Json.new)
    #   end
    #
    # @example Task-specific formatter configuration
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::Json.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #     end
    #   end
    #
    # @example Sample JSON output
    #   {"severity":"INFO","pid":1234,"timestamp":"2022-07-17T18:43:15.000000","index":0,"chain_id":"018c2b95-b764-7615","type":"Task","class":"ProcessOrderTask","id":"018c2b95-b764-7615","tags":[],"state":"complete","status":"success","outcome":"success","metadata":{},"runtime":15,"origin":"CMDx"}
    #
    # @see CMDx::LogFormatters::PrettyJson For human-readable JSON formatting
    # @see CMDx::LoggerSerializer For details on serialized data structure
    class Json

      # Formats a log entry as a single-line JSON string.
      #
      # Combines task execution metadata with severity, process ID, and timestamp
      # information to create a comprehensive JSON log entry suitable for
      # structured logging systems and log aggregation tools.
      #
      # @param severity [String] Log severity level (DEBUG, INFO, WARN, ERROR, FATAL)
      # @param time [Time] Timestamp when the log entry was created
      # @param task [CMDx::Task] Task instance being logged
      # @param message [Object] Log message or data to be included
      #
      # @return [String] Single-line JSON string with newline terminator
      #
      # @example Success log entry
      #   formatter = CMDx::LogFormatters::Json.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => {"severity":"INFO","pid":1234,...}\n
      #
      # @example Error log entry with metadata
      #   output = formatter.call("ERROR", Time.now, task, error_details)
      #   # => {"severity":"ERROR","pid":1234,"caused_failure":{...},...}\n
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

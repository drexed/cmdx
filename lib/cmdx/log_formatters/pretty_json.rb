# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Pretty JSON log formatter for CMDx logging system.
    #
    # Formats log entries as human-readable, multi-line JSON objects with proper
    # indentation and formatting. Contains the same structured data as the JSON
    # formatter but optimized for development environments and manual inspection.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyJson.new)
    #   end
    #
    # @example Task-specific formatter configuration
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::PrettyJson.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #     end
    #   end
    #
    # @example Sample pretty JSON output
    #   {
    #     "severity": "INFO",
    #     "pid": 1234,
    #     "timestamp": "2022-07-17T18:43:15.000000",
    #     "index": 0,
    #     "chain_id": "018c2b95-b764-7615",
    #     "type": "Task",
    #     "class": "ProcessOrderTask",
    #     "state": "complete",
    #     "status": "success",
    #     "outcome": "success"
    #   }
    #
    # @see CMDx::LogFormatters::Json For compact single-line JSON formatting
    # @see CMDx::LoggerSerializer For details on serialized data structure
    class PrettyJson

      # Formats a log entry as a pretty-printed JSON string.
      #
      # Combines task execution metadata with severity, process ID, and timestamp
      # information to create a human-readable JSON log entry with proper
      # indentation and formatting for development and debugging purposes.
      #
      # @param severity [String] Log severity level (DEBUG, INFO, WARN, ERROR, FATAL)
      # @param time [Time] Timestamp when the log entry was created
      # @param task [CMDx::Task] Task instance being logged
      # @param message [Object] Log message or data to be included
      #
      # @return [String] Multi-line pretty-formatted JSON string with newline terminator
      #
      # @example Success log entry
      #   formatter = CMDx::LogFormatters::PrettyJson.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => Multi-line formatted JSON output
      #
      # @example Error log entry with nested metadata
      #   output = formatter.call("ERROR", Time.now, task, error_details)
      #   # => Pretty-formatted JSON with nested failure information
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

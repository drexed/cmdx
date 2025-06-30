# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Key-value log formatter for CMDx logging system.
    #
    # Formats log entries as space-separated key=value pairs on a single line.
    # Provides a compact, structured format that is easily parseable by log
    # processing tools while remaining human-readable for basic inspection.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::KeyValue.new)
    #   end
    #
    # @example Task-specific formatter configuration
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::KeyValue.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #     end
    #   end
    #
    # @example Sample key-value output
    #   severity=INFO pid=1234 timestamp=2022-07-17T18:43:15.000000 index=0 chain_id=018c2b95-b764-7615 type=Task class=ProcessOrderTask id=018c2b95-b764-7615 tags=[] state=complete status=success outcome=success metadata={} runtime=15 origin=CMDx
    #
    # @see CMDx::LogFormatters::PrettyKeyValue For ANSI-colorized key-value formatting
    # @see CMDx::LoggerSerializer For details on serialized data structure
    class KeyValue

      # Formats a log entry as space-separated key=value pairs.
      #
      # Combines task execution metadata with severity, process ID, and timestamp
      # information to create a compact key-value log entry suitable for
      # structured logging systems that prefer flat field formats.
      #
      # @param severity [String] Log severity level (DEBUG, INFO, WARN, ERROR, FATAL)
      # @param time [Time] Timestamp when the log entry was created
      # @param task [CMDx::Task] Task instance being logged
      # @param message [Object] Log message or data to be included
      #
      # @return [String] Single-line key=value formatted string with newline terminator
      #
      # @example Success log entry
      #   formatter = CMDx::LogFormatters::KeyValue.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => "severity=INFO pid=1234 timestamp=... status=success\n"
      #
      # @example Error log entry with failure metadata
      #   output = formatter.call("ERROR", Time.now, task, error_details)
      #   # => "severity=ERROR pid=1234 ... caused_failure={...} threw_failure={...}\n"
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

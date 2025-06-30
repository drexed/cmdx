# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Pretty key-value log formatter for CMDx logging system.
    #
    # Formats log entries as space-separated key=value pairs with ANSI color
    # highlighting for improved readability in terminal environments. Provides
    # the same structured data as KeyValue formatter with enhanced visual presentation.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyKeyValue.new)
    #   end
    #
    # @example Task-specific formatter configuration
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::PrettyKeyValue.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #     end
    #   end
    #
    # @example Sample pretty key-value output (with ANSI colors)
    #   severity=INFO pid=1234 timestamp=2022-07-17T18:43:15.000000 index=0 chain_id=018c2b95-b764-7615 type=Task class=ProcessOrderTask state=complete status=success outcome=success runtime=15
    #   # Colors applied: severity levels, status values, class names, etc.
    #
    # @see CMDx::LogFormatters::KeyValue For plain key-value formatting without colors
    # @see CMDx::LoggerAnsi For ANSI color definitions
    # @see CMDx::LoggerSerializer For details on serialized data structure
    class PrettyKeyValue

      # Formats a log entry as ANSI-colorized key=value pairs.
      #
      # Combines task execution metadata with severity, process ID, and timestamp
      # information to create a visually enhanced key-value log entry with ANSI
      # color codes for improved readability in terminal environments.
      #
      # @param severity [String] Log severity level (DEBUG, INFO, WARN, ERROR, FATAL)
      # @param time [Time] Timestamp when the log entry was created
      # @param task [CMDx::Task] Task instance being logged
      # @param message [Object] Log message or data to be included
      #
      # @return [String] Single-line ANSI-colorized key=value formatted string with newline terminator
      #
      # @example Success log entry with colors
      #   formatter = CMDx::LogFormatters::PrettyKeyValue.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => ANSI-colored "severity=INFO pid=1234 ... status=success\n"
      #
      # @example Error log entry with colored failure indicators
      #   output = formatter.call("ERROR", Time.now, task, error_details)
      #   # => ANSI-colored "severity=ERROR ... status=failed\n" (red highlighting)
      #
      # @note ANSI colors are automatically applied to key elements like severity levels,
      #   status values, class names, and metadata for enhanced visual distinction
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

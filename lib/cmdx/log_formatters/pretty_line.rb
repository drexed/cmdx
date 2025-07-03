# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Pretty line log formatter for CMDx logging system.
    #
    # Formats log entries in a traditional single-line format enhanced with ANSI color
    # highlighting for improved readability in terminal environments. Provides the same
    # structured format as Line formatter with visual enhancements for severity levels,
    # status indicators, and task information.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new(STDOUT, formatter: CMDx::LogFormatters::PrettyLine.new)
    #   end
    #
    # @example Task-specific formatter configuration
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::PrettyLine.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #     end
    #   end
    #
    # @example Sample pretty line output (with ANSI colors)
    #   I, [2022-07-17T18:43:15.000000 #1234] INFO -- ProcessOrderTask: state=complete status=success outcome=success runtime=15
    #   # Colors applied: INFO in blue, success in green, class name highlighted
    #
    # @example Error pretty line output with colored failure indicators
    #   E, [2022-07-17T18:43:15.000000 #1234] ERROR -- ProcessOrderTask: state=interrupted status=failed outcome=failed
    #   # Colors applied: ERROR in red, failed in red, class name highlighted
    #
    # @see CMDx::LogFormatters::Line For plain line formatting without colors
    # @see CMDx::LoggerAnsi For ANSI color definitions
    # @see CMDx::LoggerSerializer For details on serialized data structure
    # @see CMDx::Utils::LogTimestamp For timestamp formatting
    class PrettyLine

      # Formats a log entry as an ANSI-colorized single-line log entry.
      #
      # Creates a log entry in the format: "[COLORED_SEVERITY_INITIAL], [TIMESTAMP #PID] [COLORED_SEVERITY] -- CLASS: [COLORED_MESSAGE]"
      # where colors are applied to severity indicators, status values, and other key elements.
      #
      # @param severity [String] Log severity level (DEBUG, INFO, WARN, ERROR, FATAL)
      # @param time [Time] Timestamp when the log entry was created
      # @param task [CMDx::Task] Task instance being logged
      # @param message [Object] Log message or data to be included
      #
      # @return [String] Single-line ANSI-colorized log entry with newline terminator
      #
      # @example Success log entry with colors
      #   formatter = CMDx::LogFormatters::PrettyLine.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => ANSI-colored "I, [2022-07-17T18:43:15.000000 #1234] INFO -- ProcessOrderTask: state=complete status=success\n"
      #
      # @example Warning log entry with colored indicators
      #   output = formatter.call("WARN", Time.now, task, "Order delayed")
      #   # => ANSI-colored "W, [2022-07-17T18:43:15.000000 #1234] WARN -- ProcessOrderTask: state=interrupted status=skipped\n"
      #
      # @example Error log entry with red highlighting
      #   output = formatter.call("ERROR", Time.now, task, error_details)
      #   # => ANSI-colored "E, [2022-07-17T18:43:15.000000 #1234] ERROR -- ProcessOrderTask: status=failed caused_failure={...}\n"
      #
      # @note This is the default formatter for CMDx when no specific formatter is configured
      # @note ANSI colors are automatically applied based on severity levels and status values
      def call(severity, time, task, message)
        i = LoggerAnsi.call(severity[0])
        s = LoggerAnsi.call(severity)
        t = Utils::LogTimestamp.call(time.utc)
        m = LoggerSerializer.call(severity, time, task, message, ansi_colorize: true)
        m = m.map { |k, v| "#{k}=#{v}" }.join(" ") if m.is_a?(Hash)

        "#{i}, [#{t} ##{Process.pid}] #{s} -- #{task.class.name}: #{m}\n"
      end

    end
  end
end

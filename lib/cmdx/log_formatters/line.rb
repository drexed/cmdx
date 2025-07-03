# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Line log formatter for CMDx logging system.
    #
    # Formats log entries in a traditional single-line format similar to Ruby's
    # standard Logger output. Combines severity indicators, timestamps, process
    # information, and task details in a compact, readable format suitable for
    # standard logging environments.
    #
    # @example Basic usage with global logger configuration
    #   CMDx.configure do |config|
    #     config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
    #   end
    #
    # @example Task-specific formatter configuration
    #   class ProcessOrderTask < CMDx::Task
    #     task_settings!(log_format: CMDx::LogFormatters::Line.new)
    #
    #     def call
    #       logger.info "Processing order #{order_id}"
    #     end
    #   end
    #
    # @example Sample line output
    #   I, [2022-07-17T18:43:15.000000 #1234] INFO -- ProcessOrderTask: state=complete status=success outcome=success runtime=15
    #
    # @example Error line output with failure details
    #   E, [2022-07-17T18:43:15.000000 #1234] ERROR -- ProcessOrderTask: state=interrupted status=failed outcome=failed caused_failure={...}
    #
    # @see CMDx::LogFormatters::PrettyLine For ANSI-colorized line formatting
    # @see CMDx::LoggerSerializer For details on serialized data structure
    # @see CMDx::Utils::LogTimestamp For timestamp formatting
    class Line

      # Formats a log entry as a traditional single-line log entry.
      #
      # Creates a log entry in the format: "SEVERITY_INITIAL, [TIMESTAMP #PID] SEVERITY -- CLASS: MESSAGE"
      # where MESSAGE contains key=value pairs of task execution metadata.
      #
      # @param severity [String] Log severity level (DEBUG, INFO, WARN, ERROR, FATAL)
      # @param time [Time] Timestamp when the log entry was created
      # @param task [CMDx::Task] Task instance being logged
      # @param message [Object] Log message or data to be included
      #
      # @return [String] Single-line formatted log entry with newline terminator
      #
      # @example Success log entry
      #   formatter = CMDx::LogFormatters::Line.new
      #   output = formatter.call("INFO", Time.now, task, "Order processed")
      #   # => "I, [2022-07-17T18:43:15.000000 #1234] INFO -- ProcessOrderTask: state=complete status=success\n"
      #
      # @example Debug log entry with detailed metadata
      #   output = formatter.call("DEBUG", Time.now, task, debug_info)
      #   # => "D, [2022-07-17T18:43:15.000000 #1234] DEBUG -- ProcessOrderTask: index=0 chain_id=... metadata={...}\n"
      #
      # @example Error log entry with failure chain
      #   output = formatter.call("ERROR", Time.now, task, error_details)
      #   # => "E, [2022-07-17T18:43:15.000000 #1234] ERROR -- ProcessOrderTask: status=failed caused_failure={...} threw_failure={...}\n"
      def call(severity, time, task, message)
        t = Utils::LogTimestamp.call(time.utc)
        m = LoggerSerializer.call(severity, time, task, message)
        m = m.map { |k, v| "#{k}=#{v}" }.join(" ") if m.is_a?(Hash)

        "#{severity[0]}, [#{t} ##{Process.pid}] #{severity} -- #{task.class.name}: #{m}\n"
      end

    end
  end
end

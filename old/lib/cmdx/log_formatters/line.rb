# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Line log formatter that outputs log entries in a traditional line format.
    #
    # This formatter converts log entries into a human-readable line format,
    # including metadata such as severity, process ID, and timestamp. Each log
    # entry is output as a single line with structured information.
    class Line

      # Formats a log entry as a line string.
      #
      # @param severity [String] the log severity level (e.g., "INFO", "ERROR")
      # @param time [Time] the timestamp when the log entry was created
      # @param task [Object] the task object associated with the log entry
      # @param message [String] the log message content
      #
      # @return [String] the formatted line log entry with trailing newline
      #
      # @raise [NoMethodError] if the task object doesn't respond to expected methods
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::Line.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   #=> "I, [2024-01-01T12:00:00.000Z #12345] INFO -- TaskClass: Task completed\n"
      def call(severity, time, task, message)
        t = Utils::LogTimestamp.call(time.utc)
        m = LoggerSerializer.call(severity, time, task, message)
        m = m.map { |k, v| "#{k}=#{v}" }.join(" ") if m.is_a?(Hash)

        "#{severity[0]}, [#{t} ##{Process.pid}] #{severity} -- #{task.class.name}: #{m}\n"
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Pretty line log formatter that outputs human-readable log entries with ANSI colors.
    #
    # This formatter converts log entries into a traditional log line format with
    # color-coded severity levels, timestamps, and process information. The output
    # is designed to be easily readable in terminal environments that support ANSI
    # color codes.
    #
    # @since 1.0.0
    class PrettyLine

      # Formats a log entry as a colorized human-readable line.
      #
      # @param severity [String] the log severity level (e.g., "INFO", "ERROR")
      # @param time [Time] the timestamp when the log entry was created
      # @param task [Object] the task object associated with the log entry
      # @param message [String] the log message content
      #
      # @return [String] the formatted log line with ANSI colors and trailing newline
      #
      # @raise [NoMethodError] if the task object doesn't respond to class or name methods
      # @raise [StandardError] if LoggerSerializer, LoggerAnsi, or LogTimestamp fail
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::PrettyLine.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   # => "\e[32mI\e[0m, [2024-01-01T12:00:00.000Z #12345] \e[32mINFO\e[0m -- MyTask: Task completed\n"
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

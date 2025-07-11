# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Raw log formatter that outputs log messages using inspect format.
    #
    # This formatter provides a simple, unstructured log output by calling
    # inspect on the message content. It ignores severity, time, and task
    # metadata, focusing only on the raw message content. Each log entry
    # is output as an inspected string followed by a newline character.
    class Raw

      # Formats a log entry as an inspected string.
      #
      # @param _severity [String] the log severity level (ignored)
      # @param _time [Time] the timestamp when the log entry was created (ignored)
      # @param _task [Object] the task object associated with the log entry (ignored)
      # @param message [Object] the log message content to be inspected
      #
      # @return [String] the inspected message with trailing newline
      #
      # @example Formatting a log entry
      #   formatter = CMDx::LogFormatters::Raw.new
      #   result = formatter.call("INFO", Time.now, task_object, "Task completed")
      #   # => "\"Task completed\"\n"
      #
      # @example Formatting a complex object
      #   formatter = CMDx::LogFormatters::Raw.new
      #   result = formatter.call("DEBUG", Time.now, task_object, { status: :success, count: 42 })
      #   # => "{:status=>:success, :count=>42}\n"
      def call(_severity, _time, _task, message)
        message.inspect << "\n"
      end

    end
  end
end

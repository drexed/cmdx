# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Formats log messages as raw text without additional formatting
    #
    # This formatter outputs log messages in their original form with minimal
    # processing, adding only a trailing newline. It's useful for scenarios
    # where you want to preserve the exact message content without metadata
    # or structured formatting.
    class Raw

      # Formats a log entry as raw text
      #
      # @param severity [String] The log level (e.g., "INFO", "ERROR", "DEBUG")
      # @param time [Time] The timestamp when the log entry was created
      # @param progname [String, nil] The program name or identifier
      # @param message [Object] The log message content
      #
      # @return [String] The raw message with a trailing newline
      #
      # @example Basic usage
      #   Raw.new.call("INFO", Time.now, "MyApp", "User logged in")
      #   # => "User logged in\n"
      def call(severity, time, progname, message)
        "#{message}\n"
      end

    end
  end
end

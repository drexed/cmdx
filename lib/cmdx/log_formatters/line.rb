# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Default formatter. Emits a human-readable single-line log entry that
    # mirrors Ruby's built-in `Logger::Formatter` style.
    class Line

      # @param severity [String] Logger severity name
      # @param time [Time]
      # @param progname [String, nil]
      # @param message [Object]
      # @return [String] formatted line terminated by `"\n"`
      def call(severity, time, progname, message)
        "#{severity[0]}, [#{time.utc.iso8601(6)} ##{Process.pid}] #{severity} -- #{progname}: #{message}\n"
      end

    end
  end
end

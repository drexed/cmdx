# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      def call(severity, time, progname, message)
        message = message.map { |k, v| "#{k}=#{v}" }.join(" ")
        "#{severity[0]}, [#{Utils::DatetimeFormatter.call(time.utc)} ##{Process.pid}] #{severity} -- #{progname || 'CMDx'}: #{message}"
      end

    end
  end
end

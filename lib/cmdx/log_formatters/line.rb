# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      def call(severity, time, progname, message)
        time    = Utils::DatetimeFormatter.call(time.utc)
        message = message.to_h.map { |k, v| "#{k}=#{v}" }.join(" ") if message.is_a?(Result)

        "#{severity[0]}, [#{time} ##{Process.pid}] #{severity} -- #{progname || 'CMDx'}: #{message}\n"
      end

    end
  end
end

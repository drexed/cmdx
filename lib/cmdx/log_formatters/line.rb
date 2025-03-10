# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      def call(severity, time, progname, message)
        message = message.to_h.map { |k, v| "#{k}=#{v}" }.join(" ") if message.is_a?(Result)
        "#{Utils::ColorSeverity.call(severity[0])}, [#{Utils::DatetimeFormatter.call(time.utc)} ##{Process.pid}] #{Utils::ColorSeverity.call(severity)} -- #{progname || 'CMDx'}: #{message}\n"
      end

    end
  end
end

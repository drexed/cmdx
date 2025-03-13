# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyKeyValue

      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message, ansi_colorize: true).merge!(
          severity:,
          pid: Process.pid,
          timestamp: Utils::LogTimestamp.call(time.utc)
        )

        m = m.map { |k, v| "#{k}=#{v}" }.join(" ") if m.is_a?(Hash)
        m << "\n"
      end

    end
  end
end

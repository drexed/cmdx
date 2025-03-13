# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyJson

      def call(severity, time, task, message)
        m = LoggerSerializer.call(severity, time, task, message).merge!(
          severity:,
          pid: Process.pid,
          timestamp: Utils::LogTimestamp.call(time.utc)
        )

        JSON.pretty_generate(m) << "\n"
      end

    end
  end
end

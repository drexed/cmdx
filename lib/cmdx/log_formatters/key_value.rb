# frozen_string_literal: true

module CMDx
  module LogFormatters
    class KeyValue

      def call(severity, time, progname, message)
        hash = Utils::Format.to_log(message).merge!(
          severity:,
          timestamp: time.utc.iso8601(6),
          progname:,
          pid: Process.pid
        )

        Utils::Format.to_str(hash) << "\n"
      end

    end
  end
end

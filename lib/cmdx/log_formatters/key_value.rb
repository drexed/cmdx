# frozen_string_literal: true

module CMDx
  module LogFormatters
    class KeyValue

      def call(severity, time, progname, message)
        hash = {
          severity:,
          timestamp: time.utc.iso8601(6),
          progname:,
          pid: Process.pid,
          message: Utils::Format.to_log(message)
        }

        Utils::Format.to_str(hash) << "\n"
      end

    end
  end
end

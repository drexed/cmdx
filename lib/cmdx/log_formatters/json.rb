# frozen_string_literal: true

module CMDx
  module LogFormatters
    class JSON

      def call(severity, time, progname, message)
        hash = data(severity, time, progname, message)

        ::JSON.dump(hash) << "\n"
      end

      def data(severity, time, progname, message)
        Utils::Format.to_log(message).merge!(
          severity:,
          timestamp: time.utc.iso8601(6),
          progname:,
          pid: Process.pid
        )
      end

    end
  end
end

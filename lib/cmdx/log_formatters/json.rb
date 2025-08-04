# frozen_string_literal: true

module CMDx
  module LogFormatters
    class JSON

      def call(severity, time, progname, message)
        hash =
          Utils::Format
          .to_log(message)
          .merge!(
            severity:,
            timestamp: time.utc.iso8601(6),
            progname:,
            pid: Process.pid
          )

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

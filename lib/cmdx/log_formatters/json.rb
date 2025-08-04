# frozen_string_literal: true

module CMDx
  module LogFormatters
    class JSON

      # TODO: Add program name to the log
      # TODO: https://rubyapi.org/3.4/o/logger/formatter
      # https://rubyapi.org/o/logger
      def call(severity, time, progname, message)
        hash =
          Utils::Format
          .to_log(message)
          .merge!(
            severity:,
            pid: Process.pid,
            timestamp: time.utc.iso8601(6)
          )

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

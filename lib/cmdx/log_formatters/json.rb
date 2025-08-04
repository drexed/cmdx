# frozen_string_literal: true

module CMDx
  module LogFormatters
    class JSON

      def call(severity, time, progname, message)
        hash = Utils::Format.logify(message).merge!(
          severity:,
          pid: Process.pid,
          timestamp: time.utc.iso8601(6)
        )

        ::JSON.dump(hash) << "\n"
      end

    end
  end
end

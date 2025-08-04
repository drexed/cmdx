# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      def call(severity, time, progname, message)
        hash = Utils::Format.to_log(message)
        text = Utils::Format.to_str(hash)

        "#{severity[0]}, [#{time.utc.iso8601(6)} ##{Process.pid}] #{severity} -- #{progname}: #{text}\n"
      end

    end
  end
end

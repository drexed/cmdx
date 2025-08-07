# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      def call(severity, time, progname, message)
        "#{severity[0]}, [#{time.utc.iso8601(6)} ##{Process.pid}] #{severity} -- #{progname}: #{message}\n"
      end

    end
  end
end

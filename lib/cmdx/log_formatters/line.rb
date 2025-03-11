# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      def call(severity, time, progname, message)
        timestamp = Utils::LogTimestamp.call(time.utc)
        message   = KeyValue.new.call(severity, time, progname, message).chomp

        "#{severity[0]}, [#{timestamp} ##{Process.pid}] #{severity} -- #{progname || 'CMDx'}: #{message}\n"
      end

    end
  end
end

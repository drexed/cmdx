# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyLine

      def call(severity, time, progname, message)
        indicator = LoggerAnsi.call(severity[0])
        severity  = LoggerAnsi.call(severity)
        timestamp = Utils::LogTimestamp.call(time.utc)
        message   = PrettyKeyValue.new.call(severity, time, progname, message).chomp

        "#{indicator}, [#{timestamp} ##{Process.pid}] #{severity} -- #{progname || 'CMDx'}: #{message}\n"
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyLine

      COLORED_KEYS = %i[
        state status outcome
      ].freeze

      def call(severity, time, progname, message)
        sevw = LoggerAnsi.call(severity)
        sevl = LoggerAnsi.call(severity[0])
        time = Utils::LogTimestamp.call(time.utc)

        if message.is_a?(Result)
          message = message.to_h.map do |k, v|
            v = ResultAnsi.call(v) if COLORED_KEYS.include?(k)
            "#{k}=#{v}"
          end.join(" ")
        end

        "#{sevl}, [#{time} ##{Process.pid}] #{sevw} -- #{progname || 'CMDx'}: #{message}\n"
      end

    end
  end
end

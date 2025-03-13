# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyLine

      def call(severity, time, task, message)
        i = LoggerAnsi.call(severity[0])
        s = LoggerAnsi.call(severity)
        t = Utils::LogTimestamp.call(time.utc)
        m = LoggerSerializer.call(severity, time, task, message, ansi_colorize: true)
        m = m.map { |k, v| "#{k}=#{v}" }.join(" ") if m.is_a?(Hash)

        "#{i}, [#{t} ##{Process.pid}] #{s} -- #{task.class.name}: #{m}\n"
      end

    end
  end
end

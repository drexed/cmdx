# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      def call(severity, time, task, message)
        t = Utils::LogTimestamp.call(time.utc)
        m = LoggerSerializer.call(severity, time, task, message)
        m = m.map { |k, v| "#{k}=#{v}" }.join(" ") if m.is_a?(Hash)

        "#{severity[0]}, [#{t} ##{Process.pid}] #{severity} -- #{task.class.name}: #{m}\n"
      end

    end
  end
end

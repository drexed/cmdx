# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyLine

      def call(severity, time, progname, message)
        idenifier = Utils::Paint.severity(severity[0])
        severity = Utils::Paint.severity(severity)

        hash = Line.new.data(severity, time, progname, message)

        if message.is_a?(Result)
          hash[:state] = Utils::Paint.state(hash[:state])
          hash[:status] = Utils::Paint.status(hash[:status])
        end

        text = Utils::Format.to_raw(hash)

        "#{idenifier}, [#{time.utc.iso8601(6)} ##{Process.pid}] #{severity} -- #{progname}: #{text}\n"
      end

    end
  end
end

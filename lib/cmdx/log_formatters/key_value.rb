# frozen_string_literal: true

module CMDx
  module LogFormatters
    class KeyValue

      # @rbs (untyped severity, untyped time, untyped progname, untyped msg) -> String
      def call(severity, time, _progname, msg)
        "timestamp=#{time.iso8601(6)} severity=#{severity} message=#{msg.inspect}\n"
      end

    end
  end
end

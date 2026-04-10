# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Line

      # @rbs (untyped severity, untyped time, untyped progname, untyped msg) -> String
      def call(severity, time, _progname, msg)
        "#{time.strftime('%Y-%m-%dT%H:%M:%S.%6N')} #{severity} #{msg}\n"
      end

    end
  end
end

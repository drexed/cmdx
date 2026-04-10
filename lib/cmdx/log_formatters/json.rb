# frozen_string_literal: true

module CMDx
  module LogFormatters
    class JSON

      # @rbs (untyped severity, untyped time, untyped progname, untyped msg) -> String
      def call(severity, time, _progname, msg)
        ::JSON.generate(timestamp: time.iso8601(6), severity:, message: msg) + "\n"
      end

    end
  end
end

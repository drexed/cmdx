# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Logstash

      # @rbs (untyped severity, untyped time, untyped progname, untyped msg) -> String
      def call(severity, time, _progname, msg)
        data = { "@timestamp" => time.iso8601(6), "@version" => "1", level: severity, message: msg }
        ::JSON.generate(data) + "\n"
      end

    end
  end
end

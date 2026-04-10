# frozen_string_literal: true

require "json"

module CMDx
  module LogFormatters
    # Formats log output as JSON.
    class Json

      # @param severity [String] log level
      # @param datetime [Time] timestamp
      # @param _progname [String, nil] program name
      # @param result [Result] the result to format
      #
      # @return [String] JSON-formatted log line
      #
      # @rbs (String severity, Time datetime, String? _progname, untyped result) -> String
      def call(severity, datetime, _progname, result)
        data = if result.is_a?(Result)
                 result.to_h.merge(severity:, timestamp: datetime&.iso8601)
               else
                 { message: result.to_s, severity:, timestamp: datetime&.iso8601 }
               end
        "#{::JSON.generate(data)}\n"
      end

    end
  end
end

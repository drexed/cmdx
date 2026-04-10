# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Formats log output as key=value pairs.
    class KeyValue

      # @param severity [String] log level
      # @param datetime [Time] timestamp
      # @param _progname [String, nil] program name
      # @param result [Result] the result to format
      #
      # @return [String] key=value formatted log line
      #
      # @rbs (String severity, Time datetime, String? _progname, untyped result) -> String
      def call(severity, datetime, _progname, result)
        pairs = [
          "severity=#{severity}",
          "timestamp=#{datetime&.iso8601}"
        ]

        if result.is_a?(Result)
          pairs.push(
            "task=#{result.task_class&.name}",
            "task_id=#{result.task_id}",
            "status=#{result.status}",
            "state=#{result.state}"
          )
          pairs << "reason=#{result.reason.inspect}" if result.reason
          pairs << "retries=#{result.retries}" if result.retried?
        else
          pairs << "message=#{result}"
        end

        "#{pairs.join(' ')}\n"
      end

    end
  end
end

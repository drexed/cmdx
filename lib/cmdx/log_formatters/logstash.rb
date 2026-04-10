# frozen_string_literal: true

require "json"

module CMDx
  module LogFormatters
    # Formats log output in Logstash-compatible JSON format.
    class Logstash

      # @param severity [String] log level
      # @param datetime [Time] timestamp
      # @param _progname [String, nil] program name
      # @param result [Result] the result to format
      #
      # @return [String] Logstash-compatible JSON log line
      #
      # @rbs (String severity, Time datetime, String? _progname, untyped result) -> String
      def call(severity, datetime, _progname, result)
        data = {
          "@timestamp" => datetime&.iso8601,
          "@version" => "1",
          "level" => severity
        }

        if result.is_a?(Result)
          data.merge!(
            "task" => result.task_class&.name,
            "task_id" => result.task_id,
            "task_type" => result.task_type,
            "status" => result.status,
            "state" => result.state,
            "reason" => result.reason,
            "retries" => result.retries
          )
        else
          data["message"] = result.to_s
        end

        "#{::JSON.generate(data)}\n"
      end

    end
  end
end

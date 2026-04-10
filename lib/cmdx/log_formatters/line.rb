# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Formats log output as a single human-readable line.
    class Line

      # @param _severity [String] log level
      # @param _datetime [Time] timestamp
      # @param _progname [String, nil] program name
      # @param result [Result] the result to format
      #
      # @return [String] formatted log line
      #
      # @rbs (String _severity, Time _datetime, String? _progname, untyped result) -> String
      def call(_severity, _datetime, _progname, result)
        return "#{result}\n" unless result.is_a?(Result)

        parts = [
          "[#{result.status.upcase}]",
          result.task_class&.name || "anonymous",
          "(#{result.task_id})"
        ]
        parts << "reason=#{result.reason.inspect}" if result.reason
        parts << "retries=#{result.retries}" if result.retried?
        "#{parts.join(' ')}\n"
      end

    end
  end
end

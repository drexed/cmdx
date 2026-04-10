# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Passes through the raw result hash without formatting.
    class Raw

      # @param _severity [String] log level
      # @param _datetime [Time] timestamp
      # @param _progname [String, nil] program name
      # @param result [Result] the result to format
      #
      # @return [String] raw string representation
      #
      # @rbs (String _severity, Time _datetime, String? _progname, untyped result) -> String
      def call(_severity, _datetime, _progname, result)
        data = result.is_a?(Result) ? result.to_h : result
        "#{data}\n"
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    # Passthrough formatter that writes only the message (terminated with
    # `"\n"`). Useful when surrounding infrastructure already supplies
    # severity and timestamp.
    class Raw

      # @param severity [String] ignored
      # @param time [Time] ignored
      # @param progname [String, nil] ignored
      # @param message [Object]
      # @return [String] `"#{message}\n"`
      def call(severity, time, progname, message)
        "#{message}\n"
      end

    end
  end
end

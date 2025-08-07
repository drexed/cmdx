# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Raw

      def call(severity, time, progname, message)
        "#{message}\n"
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Raw

      def call(_severity, _time, _progname, message)
        message
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Json

      def call(_severity, _time, _progname, message)
        JSON.dump(message)
      end

    end
  end
end

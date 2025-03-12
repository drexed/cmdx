# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyJson

      def call(_severity, _time, _progname, message)
        message = message.to_h if message.is_a?(Result)
        JSON.pretty_generate(message) << "\n"
      end

    end
  end
end

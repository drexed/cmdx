# frozen_string_literal: true

module CMDx
  module LogFormatters
    class KeyValue

      def call(_severity, _time, _progname, message)
        message = message.to_h.map { |k, v| "#{k}=#{v}" }.join(" ") if message.is_a?(Result)
        message << "\n"
      end

    end
  end
end

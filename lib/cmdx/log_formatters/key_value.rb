# frozen_string_literal: true

module CMDx
  module LogFormatters
    class KeyValue

      def call(_severity, _time, _progname, message)
        message.map { |k, v| "#{k}=#{v}" }.join(" ")
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyKeyValue

      COLORED_KEYS = %i[
        state status outcome
      ].freeze

      def call(_severity, _time, _progname, message)
        if message.is_a?(Result)
          message = message.to_h.map do |k, v|
            v = ResultAnsi.call(v) if COLORED_KEYS.include?(k)
            "#{k}=#{v}"
          end.join(" ")
        end

        message << "\n"
      end

    end
  end
end

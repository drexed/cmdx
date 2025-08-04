# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyKeyValue

      def call(severity, time, progname, message)
        hash = KeyValue.new.data(severity, time, progname, message)

        if message.is_a?(Result)
          hash[:state] = Utils::Paint.state(hash[:state])
          hash[:status] = Utils::Paint.status(hash[:status])
        end

        Utils::Format.to_raw(hash) << "\n"
      end

    end
  end
end

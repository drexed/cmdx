# frozen_string_literal: true

module CMDx
  module LogFormatters
    class PrettyJSON

      def call(severity, time, progname, message)
        hash = JSON.new.data(severity, time, progname, message)

        ::JSON.pretty_generate(hash) << "\n"
      end

    end
  end
end

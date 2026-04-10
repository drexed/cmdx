# frozen_string_literal: true

module CMDx
  module LogFormatters
    class Raw

      # @rbs (untyped severity, untyped time, untyped progname, untyped msg) -> String
      def call(_severity, _time, _progname, msg)
        "#{msg}\n"
      end

    end
  end
end

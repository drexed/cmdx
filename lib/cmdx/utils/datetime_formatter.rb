# frozen_string_literal: true

module CMDx
  module Utils
    module DatetimeFormatter

      DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N"

      module_function

      def call(time)
        time.strftime(DATETIME_FORMAT)
      end

    end
  end
end

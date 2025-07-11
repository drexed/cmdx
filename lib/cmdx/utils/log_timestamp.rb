# frozen_string_literal: true

module CMDx
  module Utils
    # Utility module for formatting timestamps into standardized string representations.
    #
    # This module provides functionality to convert Time objects into consistent
    # ISO 8601-like formatted strings with microsecond precision, suitable for
    # logging and timestamp display purposes.
    module LogTimestamp

      DATETIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N"

      module_function

      # Formats a Time object into a standardized timestamp string.
      #
      # @param time [Time] the time object to format
      #
      # @return [String] the formatted timestamp string in ISO 8601-like format
      #
      # @raise [NoMethodError] if the time object doesn't respond to strftime
      #
      # @example Basic timestamp formatting
      #   LogTimestamp.call(Time.now) #=> "2023-12-25T10:30:45.123456"
      #
      # @example With specific time
      #   time = Time.new(2023, 12, 25, 10, 30, 45, 123456)
      #   LogTimestamp.call(time) #=> "2023-12-25T10:30:45.123456"
      def call(time)
        time.strftime(DATETIME_FORMAT)
      end

    end
  end
end

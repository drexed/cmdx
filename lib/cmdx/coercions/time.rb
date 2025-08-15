# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Time format
    #
    # Handles conversion from strings, dates, and other time-like objects to Time
    # using Ruby's built-in time parsing methods. Supports custom strptime formats
    # and raises CoercionError for values that cannot be converted to Time.
    module Time

      extend self

      ANALOG_TYPES = %w[DateTime Time].freeze

      # Converts a value to a Time object
      #
      # @param value [Object] The value to convert to a Time object
      # @param options [Hash] Optional configuration parameters
      # @option options [String] :strptime Custom strptime format string for parsing
      #
      # @return [Time] The converted Time object
      #
      # @raise [CoercionError] If the value cannot be converted to a Time object
      #
      # @example Convert time-like objects
      #   call(Time.now)                    # => Time object (unchanged)
      #   call(DateTime.now)                # => Time object (converted)
      #   call(Date.today)                  # => Time object (converted)
      # @example Convert strings with default parsing
      #   call("2023-12-25 10:30:00")      # => Time object
      #   call("2023-12-25")               # => Time object
      #   call("10:30:00")                 # => Time object
      # @example Convert strings with custom format
      #   call("25/12/2023", strptime: "%d/%m/%Y")  # => Time object
      #   call("12-25-2023", strptime: "%m-%d-%Y")  # => Time object
      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return value.to_time if value.respond_to?(:to_time)
        return ::Time.strptime(value, options[:strptime]) if options[:strptime]

        ::Time.parse(value)
      rescue ArgumentError, TypeError
        type = Locale.t("cmdx.types.time")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

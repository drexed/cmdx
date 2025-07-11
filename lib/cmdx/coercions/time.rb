# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to Time objects.
    #
    # This coercion handles conversion of various types to Time objects, with special
    # handling for analog types (Date, DateTime, Time) and custom format parsing.
    class Time < Coercion

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      # Converts the given value to a Time object.
      #
      # @param value [Object] the value to convert to a Time object
      # @param options [Hash] optional configuration
      # @option options [String] :format custom format string for parsing
      #
      # @return [Time] the converted Time object
      #
      # @raise [CoercionError] if the value cannot be converted to a Time object
      #
      # @example Converting with custom format
      #   Coercions::Time.call('2023-12-25 14:30', format: '%Y-%m-%d %H:%M') #=> 2023-12-25 14:30:00
      #
      # @example Converting standard time strings
      #   Coercions::Time.call('2023-12-25 14:30:00') #=> 2023-12-25 14:30:00
      #   Coercions::Time.call('Dec 25, 2023') #=> 2023-12-25 00:00:00
      #
      # @example Analog types pass through unchanged
      #   time = Time.now
      #   Coercions::Time.call(time) #=> time (unchanged)
      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::Time.strptime(value, options[:format]) if options[:format]

        ::Time.parse(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "time",
          default: "could not coerce into a time"
        )
      end

    end
  end
end

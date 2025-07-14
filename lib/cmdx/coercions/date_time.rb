# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to DateTime objects.
    #
    # This coercion handles conversion of various types to DateTime objects,
    # with support for custom date/time formats and automatic detection of
    # analog types (Date, DateTime, Time).
    class DateTime < Coercion

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      # Converts the given value to a DateTime object.
      #
      # @param value [Object] the value to convert to a DateTime
      # @param options [Hash] optional configuration
      # @option options [String] :strptime custom format string for parsing
      #
      # @return [DateTime] the converted DateTime object
      #
      # @raise [CoercionError] if the value cannot be converted to a DateTime
      #
      # @example Converting a date string
      #   Coercions::DateTime.call('2023-12-25') #=> #<DateTime: 2023-12-25T00:00:00+00:00>
      #
      # @example Converting with a custom format
      #   Coercions::DateTime.call('25/12/2023', strptime: '%d/%m/%Y') #=> #<DateTime: 2023-12-25T00:00:00+00:00>
      #
      # @example Passing through existing DateTime objects
      #   dt = DateTime.now
      #   Coercions::DateTime.call(dt) #=> dt (unchanged)
      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::DateTime.strptime(value, options[:strptime]) if options[:strptime]

        ::DateTime.parse(value)
      rescue TypeError, ::Date::Error
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "datetime",
          default: "could not coerce into a datetime"
        )
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Coercion class for converting values to Date objects.
    #
    # This coercion handles conversion of various types to Date objects, with support
    # for custom date formats and automatic detection of date-like objects.
    #
    # @since 1.0.0
    class Date < Coercion

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      # Converts the given value to a Date object.
      #
      # @param value [Object] the value to convert to a Date
      # @param options [Hash] optional configuration
      # @option options [String] :format custom date format for parsing
      #
      # @return [Date] the converted Date object
      #
      # @raise [CoercionError] if the value cannot be converted to a Date
      #
      # @example Converting a string with default parsing
      #   Coercions::Date.call('2023-12-25') #=> #<Date: 2023-12-25>
      #
      # @example Converting with custom format
      #   Coercions::Date.call('25/12/2023', format: '%d/%m/%Y') #=> #<Date: 2023-12-25>
      #
      # @example Converting existing date-like objects
      #   Coercions::Date.call(DateTime.now) #=> #<Date: 2023-12-25>
      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::Date.strptime(value, options[:format]) if options[:format]

        ::Date.parse(value)
      rescue TypeError, ::Date::Error
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "date",
          default: "could not coerce into a date"
        )
      end

    end
  end
end

# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to Date format
    #
    # Handles conversion from strings, Date objects, DateTime objects, Time objects,
    # and other date-like values to Date objects using Ruby's built-in parsing
    # capabilities and optional custom format parsing.
    module Date

      extend self

      # Types that are already date-like and don't need conversion
      #
      # @rbs ANALOG_TYPES: Array[String]
      ANALOG_TYPES = %w[Date DateTime Time].freeze

      # Converts a value to a Date object
      #
      # @param value [Object] The value to convert to a Date
      # @param options [Hash] Optional configuration parameters
      # @option options [String] :strptime Custom date format string for parsing
      #
      # @return [Date] The converted Date object
      #
      # @raise [CoercionError] If the value cannot be converted to a Date
      #
      # @example Convert string to Date using default parsing
      #   Date.call("2023-12-25")           # => #<Date: 2023-12-25>
      #   Date.call("Dec 25, 2023")        # => #<Date: 2023-12-25>
      # @example Convert string using custom format
      #   Date.call("25/12/2023", strptime: "%d/%m/%Y")  # => #<Date: 2023-12-25>
      #   Date.call("12-25-2023", strptime: "%m-%d-%Y")  # => #<Date: 2023-12-25>
      # @example Return existing Date objects unchanged
      #   Date.call(Date.new(2023, 12, 25)) # => #<Date: 2023-12-25>
      #   Date.call(DateTime.new(2023, 12, 25)) # => #<Date: 2023-12-25>
      #
      # @rbs (untyped value, ?Hash[Symbol, untyped] options) -> Date
      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::Date.strptime(value, options[:strptime]) if options[:strptime]

        ::Date.parse(value)
      rescue TypeError, ::Date::Error
        type = Locale.t("cmdx.types.date")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

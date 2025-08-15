# frozen_string_literal: true

module CMDx
  module Coercions
    # Converts various input types to DateTime format
    #
    # Handles conversion from date strings, Date objects, Time objects, and other
    # values that can be converted to DateTime using Ruby's DateTime.parse method
    # or custom strptime formats.
    module DateTime

      extend self

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      # Converts a value to a DateTime
      #
      # @param value [Object] The value to convert to DateTime
      # @param options [Hash] Optional configuration parameters
      # @option options [String] :strptime Custom date format string for parsing
      #
      # @return [DateTime] The converted DateTime value
      #
      # @raise [CoercionError] If the value cannot be converted to DateTime
      #
      # @example Convert date strings to DateTime
      #   DateTime.call("2023-12-25")               # => #<DateTime: 2023-12-25T00:00:00+00:00>
      #   DateTime.call("Dec 25, 2023")             # => #<DateTime: 2023-12-25T00:00:00+00:00>
      # @example Convert with custom strptime format
      #   DateTime.call("25/12/2023", strptime: "%d/%m/%Y")
      #   # => #<DateTime: 2023-12-25T00:00:00+00:00>
      # @example Convert existing date objects
      #   DateTime.call(Date.new(2023, 12, 25))     # => #<DateTime: 2023-12-25T00:00:00+00:00>
      #   DateTime.call(Time.new(2023, 12, 25))     # => #<DateTime: 2023-12-25T00:00:00+00:00>
      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::DateTime.strptime(value, options[:strptime]) if options[:strptime]

        ::DateTime.parse(value)
      rescue TypeError, ::Date::Error
        type = Locale.t("cmdx.types.date_time")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end

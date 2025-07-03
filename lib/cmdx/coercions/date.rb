# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Date type.
    #
    # The Date coercion converts parameter values to Date objects
    # with support for date parsing, custom format strings, and
    # automatic handling of date-like objects.
    #
    # @example Basic date coercion
    #   class ProcessOrderTask < CMDx::Task
    #     required :order_date, type: :date
    #     optional :delivery_date, type: :date, format: "%Y-%m-%d"
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Date.call("2023-12-25")                    # => Date object
    #   Coercions::Date.call("25/12/2023", format: "%d/%m/%Y") # Custom format
    #   Coercions::Date.call(Time.now)                        # => Date (from Time)
    #   Coercions::Date.call("invalid")                       # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    module Date

      # Date-compatible class names that are passed through unchanged
      # @return [Array<String>] class names that represent date-like objects
      ANALOG_TYPES = %w[Date DateTime Time].freeze

      module_function

      # Coerce a value to Date.
      #
      # Handles multiple input formats:
      # - Date, DateTime, Time objects (returned as Date)
      # - String with custom format (parsed using strptime)
      # - String with standard format (parsed using Date.parse)
      #
      # @param value [Object] value to coerce to date
      # @param options [Hash] coercion options
      # @option options [String] :format custom date format string
      # @return [Date] coerced date value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::Date.call("2023-12-25")                      # => Date
      #   Coercions::Date.call("25/12/2023", format: "%d/%m/%Y")  # => Date with custom format
      #   Coercions::Date.call(Time.now)                          # => Date from Time
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

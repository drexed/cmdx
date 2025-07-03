# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to DateTime type.
    #
    # The DateTime coercion converts parameter values to DateTime objects
    # with support for datetime parsing, custom format strings, and
    # automatic handling of date/time-like objects.
    #
    # @example Basic datetime coercion
    #   class ProcessOrderTask < CMDx::Task
    #     required :order_datetime, type: :date_time
    #     optional :delivery_datetime, type: :date_time, format: "%Y-%m-%d %H:%M:%S"
    #   end
    #
    # @example Coercion behavior
    #   Coercions::DateTime.call("2023-12-25T14:30:00")                    # => DateTime object
    #   Coercions::DateTime.call("25/12/2023 2:30 PM", format: "%d/%m/%Y %l:%M %p") # Custom format
    #   Coercions::DateTime.call(Time.now)                                 # => DateTime (from Time)
    #   Coercions::DateTime.call("invalid")                                # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    module DateTime

      # DateTime-compatible class names that are passed through unchanged
      # @return [Array<String>] class names that represent datetime-like objects
      ANALOG_TYPES = %w[Date DateTime Time].freeze

      module_function

      # Coerce a value to DateTime.
      #
      # Handles multiple input formats:
      # - Date, DateTime, Time objects (returned as-is)
      # - String with custom format (parsed using strptime)
      # - String with standard format (parsed using DateTime.parse)
      #
      # @param value [Object] value to coerce to datetime
      # @param options [Hash] coercion options
      # @option options [String] :format custom datetime format string
      # @return [DateTime] coerced datetime value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::DateTime.call("2023-12-25T14:30:00")                      # => DateTime
      #   Coercions::DateTime.call("25/12/2023 14:30", format: "%d/%m/%Y %H:%M") # => DateTime with custom format
      #   Coercions::DateTime.call(Time.now)                                    # => DateTime from Time
      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::DateTime.strptime(value, options[:format]) if options[:format]

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

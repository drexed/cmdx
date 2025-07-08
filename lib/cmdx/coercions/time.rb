# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Time type.
    #
    # The Time coercion converts parameter values to Time objects
    # with support for time parsing, custom format strings, and
    # automatic handling of time-like objects.
    #
    # @example Basic time coercion
    #   class ProcessOrderTask < CMDx::Task
    #     required :created_at, type: :time
    #     optional :scheduled_at, type: :time, format: "%Y-%m-%d %H:%M:%S"
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Time.call("2023-12-25 14:30:00")                      # => Time object
    #   Coercions::Time.call("25/12/2023 2:30 PM", format: "%d/%m/%Y %l:%M %p") # Custom format
    #   Coercions::Time.call(Date.today)                                 # => Time (from Date)
    #   Coercions::Time.call("invalid")                                  # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    class Time < Coercion

      # Time-compatible class names that are passed through unchanged
      # @return [Array<String>] class names that represent time-like objects
      ANALOG_TYPES = %w[Date DateTime Time].freeze

      # Coerce a value to Time.
      #
      # Handles multiple input formats:
      # - Date, DateTime, Time objects (returned as-is)
      # - String with custom format (parsed using strptime)
      # - String with standard format (parsed using Time.parse)
      #
      # @param value [Object] value to coerce to time
      # @param options [Hash] coercion options
      # @option options [String] :format custom time format string
      # @return [Time] coerced time value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::Time.call("2023-12-25 14:30:00")                        # => Time
      #   Coercions::Time.call("25/12/2023 14:30", format: "%d/%m/%Y %H:%M") # => Time with custom format
      #   Coercions::Time.call(DateTime.now)                                 # => Time from DateTime
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

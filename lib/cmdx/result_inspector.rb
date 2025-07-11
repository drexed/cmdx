# frozen_string_literal: true

module CMDx
  # Provides formatted inspection functionality for task execution results.
  #
  # This module formats result hash data into a human-readable string representation
  # with ordered key-value pairs. It handles special formatting for specific keys
  # like failure references and applies consistent ordering to result attributes.
  module ResultInspector

    ORDERED_KEYS = %i[
      class type index id state status outcome metadata
      tags pid runtime caused_failure threw_failure
    ].freeze

    module_function

    # Formats a result hash into a human-readable inspection string.
    #
    # Creates a formatted string representation of a result hash with ordered
    # key-value pairs. Special keys like :class, :caused_failure, and :threw_failure
    # receive custom formatting for better readability and debugging.
    #
    # @param result [Hash] the result hash to format and inspect
    #
    # @return [String] formatted string with space-separated key-value pairs
    #
    # @raise [NoMethodError] if result doesn't respond to key? or []
    #
    # @example Formatting a basic result
    #   result = { class: "MyTask", state: "complete", status: "success" }
    #   ResultInspector.call(result)
    #   # => "MyTask: state=complete status=success"
    #
    # @example Formatting result with failure information
    #   result = {
    #     class: "ProcessTask",
    #     state: "interrupted",
    #     caused_failure: { index: 2, class: "ValidationError", id: "val_123" }
    #   }
    #   ResultInspector.call(result)
    #   # => "ProcessTask: state=interrupted caused_failure=<[2] ValidationError: val_123>"
    #
    # @example Formatting empty or minimal result
    #   result = { id: "task_456" }
    #   ResultInspector.call(result)
    #   # => "id=task_456"
    def call(result)
      ORDERED_KEYS.filter_map do |key|
        next unless result.key?(key)

        value = result[key]

        case key
        when :class
          "#{value}:"
        when :caused_failure, :threw_failure
          "#{key}=<[#{value[:index]}] #{value[:class]}: #{value[:id]}>"
        else
          "#{key}=#{value}"
        end
      end.join(" ")
    end

  end
end

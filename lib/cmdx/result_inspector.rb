# frozen_string_literal: true

module CMDx
  # Result inspection and formatting utilities for readable result representation.
  #
  # This module provides functionality to format result metadata into human-readable
  # strings for debugging, logging, and introspection purposes. It processes result
  # hashes and displays essential result information in a structured, ordered format
  # that emphasizes the most important attributes first.
  module ResultInspector

    ORDERED_KEYS = %i[
      class type index id state status outcome metadata
      tags pid runtime caused_failure threw_failure
    ].freeze

    module_function

    # Formats a result hash into a human-readable string representation.
    #
    # This method converts result metadata into a structured string format that
    # displays key result information in a predefined order. It handles special
    # formatting for class names, failure references, and standard key-value pairs.
    # The method filters the result hash to only include keys defined in ORDERED_KEYS
    # and applies appropriate formatting based on the key type.
    #
    # @param result [Hash] the result hash to format
    # @option result [String] :class the class name of the task or workflow
    # @option result [String] :type the type identifier (e.g., "Task", "Workflow")
    # @option result [Integer] :index the position index in the execution chain
    # @option result [String] :id the unique identifier of the result
    # @option result [String] :state the execution state (e.g., "executed", "skipped")
    # @option result [String] :status the execution status (e.g., "success", "failure")
    # @option result [String] :outcome the overall outcome (e.g., "good", "bad")
    # @option result [Hash] :metadata additional metadata associated with the result
    # @option result [Array] :tags the tags associated with the result
    # @option result [Integer] :pid the process ID if applicable
    # @option result [Float] :runtime the execution runtime in seconds
    # @option result [Hash] :caused_failure reference to a failure this result caused
    # @option result [Hash] :threw_failure reference to a failure this result threw
    #
    # @return [String] a formatted string representation of the result with key information
    #
    # @example Format a successful task result
    #   result = MyTask.call
    #   ResultInspector.call(result)
    #   # => "MyTask: type=Task index=0 id=abc123 state=executed status=success outcome=good"
    #
    # @example Format a result with failure reference
    #   result = MyTask.call
    #   ResultInspector.call(result)
    #   # => "MyTask: index=1 state=executed status=failure caused_failure=<[2] ValidationError: def456>"
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

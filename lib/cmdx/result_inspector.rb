# frozen_string_literal: true

module CMDx
  # Result inspection utility for generating human-readable result descriptions.
  #
  # The ResultInspector module provides functionality to convert result hash
  # representations into formatted, human-readable strings. It handles special
  # formatting for different result attributes and provides consistent ordering
  # of result information.
  #
  # @example Basic result inspection
  #   result_hash = {
  #     class: "ProcessOrderTask",
  #     type: "Task",
  #     index: 0,
  #     id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #     state: "complete",
  #     status: "success",
  #     outcome: "success",
  #     metadata: { order_id: 123 },
  #     runtime: 0.5
  #   }
  #
  #   ResultInspector.call(result_hash)
  #   # => "ProcessOrderTask: type=Task index=0 id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=complete status=success outcome=success metadata={order_id: 123} runtime=0.5"
  #
  # @example Result with failure information
  #   failed_result = {
  #     class: "ProcessOrderTask",
  #     type: "Task",
  #     index: 1,
  #     id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #     state: "interrupted",
  #     status: "failed",
  #     outcome: "failed",
  #     caused_failure: { index: 0, class: "ValidationTask", id: "018c2b95..." },
  #     threw_failure: { index: 0, class: "ValidationTask", id: "018c2b95..." }
  #   }
  #
  #   ResultInspector.call(failed_result)
  #   # => "ProcessOrderTask: type=Task index=1 id=018c2b95... state=interrupted status=failed outcome=failed caused_failure=<[0] ValidationTask: 018c2b95...> threw_failure=<[0] ValidationTask: 018c2b95...>"
  #
  # @see CMDx::Result Result hash serialization via to_h
  # @see CMDx::ResultSerializer Result-to-hash conversion
  module ResultInspector

    # Ordered keys for consistent result inspection output.
    #
    # Defines the order in which result attributes are displayed in the
    # inspection string, ensuring consistent and logical presentation.
    ORDERED_KEYS = %i[
      class type index id state status outcome metadata
      tags pid runtime caused_failure threw_failure
    ].freeze

    module_function

    # Converts a result hash to a human-readable string representation.
    #
    # Formats result data into a structured string with proper ordering and
    # special handling for different attribute types. The class name appears
    # first followed by a colon, and failure references are specially formatted.
    #
    # @param result [Hash] The result hash to inspect
    # @return [String] Formatted result description
    #
    # @example Simple result inspection
    #   ResultInspector.call(result_hash)
    #   # => "ProcessOrderTask: type=Task index=0 id=018c2b95... state=complete status=success"
    #
    # @example Result with metadata
    #   result_with_metadata = { class: "MyTask", metadata: { user_id: 123, action: "create" } }
    #   ResultInspector.call(result_with_metadata)
    #   # => "MyTask: metadata={user_id: 123, action: create}"
    #
    # @example Result with failure references
    #   result_with_failures = {
    #     class: "MainTask",
    #     caused_failure: { index: 2, class: "SubTask", id: "abc123" },
    #     threw_failure: { index: 1, class: "HelperTask", id: "def456" }
    #   }
    #   ResultInspector.call(result_with_failures)
    #   # => "MainTask: caused_failure=<[2] SubTask: abc123> threw_failure=<[1] HelperTask: def456>"
    #
    # @example Result with runtime information
    #   result_with_runtime = { class: "SlowTask", runtime: 2.5, pid: 1234 }
    #   ResultInspector.call(result_with_runtime)
    #   # => "SlowTask: runtime=2.5 pid=1234"
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

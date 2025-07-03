# frozen_string_literal: true

module CMDx
  # Chain inspection utility for generating comprehensive chain summaries.
  #
  # The ChainInspector module provides functionality to convert Chain instances
  # into detailed, human-readable string representations. It creates formatted
  # summaries that include chain metadata, all task results, and summary statistics
  # with visual separators for easy debugging and monitoring.
  #
  # @example Basic chain inspection
  #   result = ProcessOrderTask.call(order_id: 123)
  #   chain = result.chain
  #
  #   ChainInspector.call(chain)
  #   # => "
  #   #   chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
  #   #   ================================================
  #   #
  #   #   {
  #   #     class: "ProcessOrderTask",
  #   #     type: "Task",
  #   #     index: 0,
  #   #     id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #     tags: [],
  #   #     state: "complete",
  #   #     status: "success",
  #   #     outcome: "success",
  #   #     metadata: {},
  #   #     runtime: 0.5
  #   #   }
  #   #
  #   #   ================================================
  #   #   state: complete | status: success | outcome: success | runtime: 0.5
  #   #   "
  #
  # @example Chain with multiple tasks
  #   class ComplexTask < CMDx::Task
  #     def call
  #       SubTask1.call(context)
  #       SubTask2.call(context)
  #     end
  #   end
  #
  #   result = ComplexTask.call
  #   ChainInspector.call(result.chain)
  #   # => Shows formatted output with all three task results and summary
  #
  # @example Failed chain inspection
  #   # When a chain contains failed tasks, the summary reflects the failure state
  #   ChainInspector.call(failed_chain)
  #   # => Shows all task results with failure information and failed summary
  #
  # @see CMDx::Chain Chain execution context and result tracking
  # @see CMDx::Result Individual result inspection via to_h
  module ChainInspector

    # Keys to display in the chain summary footer.
    #
    # These keys represent the most important chain-level information
    # that should be displayed in the summary footer for quick reference.
    FOOTER_KEYS = %i[
      state status outcome runtime
    ].freeze

    module_function

    # Converts a Chain instance to a comprehensive string representation.
    #
    # Creates a formatted summary that includes:
    # - Chain header with unique ID
    # - Visual separator line
    # - Pretty-printed hash representation of each result
    # - Visual separator line
    # - Summary footer with key chain statistics
    #
    # @param chain [CMDx::Chain] The chain instance to inspect
    # @return [String] Formatted chain summary with task details and statistics
    #
    # @example Single task chain
    #   chain = SimpleTask.call.chain
    #   ChainInspector.call(chain)
    #   # => "
    #   #   chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
    #   #   ================================================
    #   #
    #   #   {
    #   #     class: "SimpleTask",
    #   #     type: "Task",
    #   #     index: 0,
    #   #     state: "complete",
    #   #     status: "success",
    #   #     outcome: "success",
    #   #     runtime: 0.1
    #   #   }
    #   #
    #   #   ================================================
    #   #   state: complete | status: success | outcome: success | runtime: 0.1
    #   #   "
    #
    # @example Multi-task chain
    #   class ParentTask < CMDx::Task
    #     def call
    #       ChildTask1.call(context)
    #       ChildTask2.call(context)
    #     end
    #   end
    #
    #   chain = ParentTask.call.chain
    #   ChainInspector.call(chain)
    #   # => "
    #   #   chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
    #   #   ================================================
    #   #
    #   #   { class: "ParentTask", index: 0, state: "complete", status: "success", ... }
    #   #   { class: "ChildTask1", index: 1, state: "complete", status: "success", ... }
    #   #   { class: "ChildTask2", index: 2, state: "complete", status: "success", ... }
    #   #
    #   #   ================================================
    #   #   state: complete | status: success | outcome: success | runtime: 0.5
    #   #   "
    #
    # @example Failed chain inspection
    #   failed_chain = FailingTask.call.chain
    #   ChainInspector.call(failed_chain)
    #   # => "
    #   #   chain: 018c2b95-b764-7615-a924-cc5b910ed1e5
    #   #   ================================================
    #   #
    #   #   { class: "FailingTask", state: "interrupted", status: "failed", metadata: { reason: "Error" }, ... }
    #   #
    #   #   ================================================
    #   #   state: interrupted | status: failed | outcome: failed | runtime: 0.1
    #   #   "
    def call(chain)
      header = "\nchain: #{chain.id}"
      footer = FOOTER_KEYS.map { |key| "#{key}: #{chain.send(key)}" }.join(" | ")
      spacer = "=" * [header.size, footer.size].max

      chain
        .results
        .map { |r| r.to_h.except(:chain_id).pretty_inspect }
        .unshift(header, "#{spacer}\n")
        .push(spacer, "#{footer}\n\n")
        .join("\n")
    end

  end
end

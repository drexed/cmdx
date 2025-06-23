# frozen_string_literal: true

module CMDx
  # Run inspection utility for generating comprehensive run summaries.
  #
  # The RunInspector module provides functionality to convert Run instances
  # into detailed, human-readable string representations. It creates formatted
  # summaries that include run metadata, all task results, and summary statistics
  # with visual separators for easy debugging and monitoring.
  #
  # @example Basic run inspection
  #   result = ProcessOrderTask.call(order_id: 123)
  #   run = result.run
  #
  #   RunInspector.call(run)
  #   # => "
  #   #   run: 018c2b95-b764-7615-a924-cc5b910ed1e5
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
  # @example Run with multiple tasks
  #   class ComplexTask < CMDx::Task
  #     def call
  #       SubTask1.call(context)
  #       SubTask2.call(context)
  #     end
  #   end
  #
  #   result = ComplexTask.call
  #   RunInspector.call(result.run)
  #   # => Shows formatted output with all three task results and summary
  #
  # @example Failed run inspection
  #   # When a run contains failed tasks, the summary reflects the failure state
  #   RunInspector.call(failed_run)
  #   # => Shows all task results with failure information and failed summary
  #
  # @see CMDx::Run Run execution context and result tracking
  # @see CMDx::Result Individual result inspection via to_h
  module RunInspector

    # Keys to display in the run summary footer.
    #
    # These keys represent the most important run-level information
    # that should be displayed in the summary footer for quick reference.
    FOOTER_KEYS = %i[
      state status outcome runtime
    ].freeze

    module_function

    # Converts a Run instance to a comprehensive string representation.
    #
    # Creates a formatted summary that includes:
    # - Run header with unique ID
    # - Visual separator line
    # - Pretty-printed hash representation of each result
    # - Visual separator line
    # - Summary footer with key run statistics
    #
    # @param run [CMDx::Run] The run instance to inspect
    # @return [String] Formatted run summary with task details and statistics
    #
    # @example Single task run
    #   run = SimpleTask.call.run
    #   RunInspector.call(run)
    #   # => "
    #   #   run: 018c2b95-b764-7615-a924-cc5b910ed1e5
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
    # @example Multi-task run
    #   class ParentTask < CMDx::Task
    #     def call
    #       ChildTask1.call(context)
    #       ChildTask2.call(context)
    #     end
    #   end
    #
    #   run = ParentTask.call.run
    #   RunInspector.call(run)
    #   # => "
    #   #   run: 018c2b95-b764-7615-a924-cc5b910ed1e5
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
    # @example Failed run inspection
    #   failed_run = FailingTask.call.run
    #   RunInspector.call(failed_run)
    #   # => "
    #   #   run: 018c2b95-b764-7615-a924-cc5b910ed1e5
    #   #   ================================================
    #   #
    #   #   { class: "FailingTask", state: "interrupted", status: "failed", metadata: { reason: "Error" }, ... }
    #   #
    #   #   ================================================
    #   #   state: interrupted | status: failed | outcome: failed | runtime: 0.1
    #   #   "
    def call(run)
      header = "\nrun: #{run.id}"
      footer = FOOTER_KEYS.map { |key| "#{key}: #{run.send(key)}" }.join(" | ")
      spacer = "=" * [header.size, footer.size].max

      run
        .results
        .map { |r| r.to_h.except(:run_id).pretty_inspect }
        .unshift(header, "#{spacer}\n")
        .push(spacer, "#{footer}\n\n")
        .join("\n")
    end

  end
end

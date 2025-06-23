# frozen_string_literal: true

module CMDx
  # Run serialization utility for converting Run objects to hash representations.
  #
  # The RunSerializer module provides functionality to serialize Run instances
  # into structured hash representations suitable for inspection, logging,
  # debugging, and data interchange. It creates comprehensive data structures
  # that include run metadata and all associated task results.
  #
  # @example Basic run serialization
  #   result = ProcessOrderTask.call(order_id: 123)
  #   run = result.run
  #
  #   RunSerializer.call(run)
  #   # => {
  #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #   state: "complete",
  #   #   status: "success",
  #   #   outcome: "success",
  #   #   runtime: 0.5,
  #   #   results: [
  #   #     {
  #   #       class: "ProcessOrderTask",
  #   #       type: "Task",
  #   #       index: 0,
  #   #       id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #       run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #       tags: [],
  #   #       state: "complete",
  #   #       status: "success",
  #   #       outcome: "success",
  #   #       metadata: {},
  #   #       runtime: 0.5
  #   #     }
  #   #   ]
  #   # }
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
  #   run = result.run
  #
  #   RunSerializer.call(run)
  #   # => {
  #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #   state: "complete",
  #   #   status: "success",
  #   #   outcome: "success",
  #   #   runtime: 1.2,
  #   #   results: [
  #   #     { class: "ComplexTask", index: 0, state: "complete", status: "success", ... },
  #   #     { class: "SubTask1", index: 1, state: "complete", status: "success", ... },
  #   #     { class: "SubTask2", index: 2, state: "complete", status: "success", ... }
  #   #   ]
  #   # }
  #
  # @example Failed run serialization
  #   failed_result = FailingTask.call
  #   failed_run = failed_result.run
  #
  #   RunSerializer.call(failed_run)
  #   # => {
  #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #   state: "interrupted",
  #   #   status: "failed",
  #   #   outcome: "failed",
  #   #   runtime: 0.1,
  #   #   results: [
  #   #     {
  #   #       class: "FailingTask",
  #   #       state: "interrupted",
  #   #       status: "failed",
  #   #       outcome: "failed",
  #   #       metadata: { reason: "Something went wrong" },
  #   #       runtime: 0.1,
  #   #       ...
  #   #     }
  #   #   ]
  #   # }
  #
  # @see CMDx::Run Run execution context and result tracking
  # @see CMDx::ResultSerializer Individual result serialization
  # @see CMDx::RunInspector Human-readable run formatting
  module RunSerializer

    module_function

    # Converts a Run object to a hash representation.
    #
    # Serializes a Run instance into a structured hash containing run metadata
    # and all associated task results. The run-level data is derived from the
    # first result in the collection, while all individual results are included
    # in their full serialized form.
    #
    # @param run [CMDx::Run] The run object to serialize
    # @return [Hash] Structured hash representation of the run and all results
    #
    # @example Simple run serialization
    #   run = SimpleTask.call.run
    #   RunSerializer.call(run)
    #   # => {
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: "complete",
    #   #   status: "success",
    #   #   outcome: "success",
    #   #   runtime: 0.1,
    #   #   results: [
    #   #     {
    #   #       class: "SimpleTask",
    #   #       type: "Task",
    #   #       index: 0,
    #   #       id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #       run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #       tags: [],
    #   #       state: "complete",
    #   #       status: "success",
    #   #       outcome: "success",
    #   #       metadata: {},
    #   #       runtime: 0.1
    #   #     }
    #   #   ]
    #   # }
    #
    # @example Multi-task run serialization
    #   class ParentTask < CMDx::Task
    #     def call
    #       ChildTask.call(context)
    #     end
    #   end
    #
    #   run = ParentTask.call.run
    #   RunSerializer.call(run)
    #   # => {
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: "complete",      # From first result (ParentTask)
    #   #   status: "success",      # From first result (ParentTask)
    #   #   outcome: "success",     # From first result (ParentTask)
    #   #   runtime: 0.5,          # From first result (ParentTask)
    #   #   results: [
    #   #     { class: "ParentTask", index: 0, ... },
    #   #     { class: "ChildTask", index: 1, ... }
    #   #   ]
    #   # }
    #
    # @example Empty run serialization
    #   empty_run = Run.new
    #   RunSerializer.call(empty_run)
    #   # => {
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: nil,
    #   #   status: nil,
    #   #   outcome: nil,
    #   #   runtime: nil,
    #   #   results: []
    #   # }
    def call(run)
      {
        id: run.id,
        state: run.state,
        status: run.status,
        outcome: run.outcome,
        runtime: run.runtime,
        results: run.results.map(&:to_h)
      }
    end

  end
end

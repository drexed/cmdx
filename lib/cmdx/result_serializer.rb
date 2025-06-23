# frozen_string_literal: true

module CMDx
  # Result serialization utility for converting Result objects to hash representations.
  #
  # The ResultSerializer module provides functionality to serialize Result instances
  # into structured hash representations suitable for inspection, logging, debugging,
  # and data interchange. It handles failure chain information and integrates with
  # TaskSerializer for comprehensive result data.
  #
  # @example Basic result serialization
  #   task = ProcessOrderTask.call(order_id: 123)
  #   result = task.result
  #
  #   ResultSerializer.call(result)
  #   # => {
  #   #   class: "ProcessOrderTask",
  #   #   type: "Task",
  #   #   index: 0,
  #   #   run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #   tags: [],
  #   #   state: "complete",
  #   #   status: "success",
  #   #   outcome: "success",
  #   #   metadata: {},
  #   #   runtime: 0.5
  #   # }
  #
  # @example Failed result serialization
  #   task = ProcessOrderTask.new
  #   task.fail!(reason: "Invalid order data", code: 422)
  #   result = task.result
  #
  #   ResultSerializer.call(result)
  #   # => {
  #   #   class: "ProcessOrderTask",
  #   #   type: "Task",
  #   #   index: 0,
  #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
  #   #   state: "interrupted",
  #   #   status: "failed",
  #   #   outcome: "failed",
  #   #   metadata: { reason: "Invalid order data", code: 422 },
  #   #   runtime: 0.1,
  #   #   caused_failure: { ... },  # Failure chain information
  #   #   threw_failure: { ... }
  #   # }
  #
  # @example Result with failure chain
  #   # When a result has failure chain information, it's included but
  #   # stripped of recursive caused_failure/threw_failure to prevent cycles
  #   ResultSerializer.call(result_with_failures)
  #   # => {
  #   #   # ... standard result data ...
  #   #   caused_failure: {
  #   #     class: "ValidationTask",
  #   #     index: 1,
  #   #     state: "interrupted",
  #   #     status: "failed"
  #   #     # caused_failure and threw_failure are stripped to prevent recursion
  #   #   },
  #   #   threw_failure: {
  #   #     class: "ProcessingTask",
  #   #     index: 2,
  #   #     state: "interrupted",
  #   #     status: "failed"
  #   #     # caused_failure and threw_failure are stripped to prevent recursion
  #   #   }
  #   # }
  #
  # @see CMDx::Result Result object creation and state management
  # @see CMDx::TaskSerializer Task serialization functionality
  # @see CMDx::ResultInspector Human-readable result formatting
  module ResultSerializer

    # Proc for stripping failure chain information to prevent recursion.
    #
    # This proc is used to include failure chain information (caused_failure
    # and threw_failure) while preventing infinite recursion by stripping
    # the same fields from nested failure objects.
    STRIP_FAILURE = proc do |h, r, k|
      unless r.send(:"#{k}?")
        # Strip caused/threw failures since its the same info as the log line
        h[k] = r.send(k).to_h.except(:caused_failure, :threw_failure)
      end
    end.freeze

    module_function

    # Converts a Result object to a hash representation.
    #
    # Serializes a Result instance into a structured hash containing all
    # relevant result information including task data, execution state,
    # status, metadata, runtime, and failure chain information.
    #
    # @param result [CMDx::Result] The result object to serialize
    # @return [Hash] Structured hash representation of the result
    #
    # @example Successful result serialization
    #   result = ProcessOrderTask.call(order_id: 123).result
    #   ResultSerializer.call(result)
    #   # => {
    #   #   class: "ProcessOrderTask",
    #   #   type: "Task",
    #   #   index: 0,
    #   #   run_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   tags: [],
    #   #   state: "complete",
    #   #   status: "success",
    #   #   outcome: "success",
    #   #   metadata: {},
    #   #   runtime: 0.5
    #   # }
    #
    # @example Failed result with metadata
    #   task = ProcessOrderTask.new
    #   task.fail!(reason: "Validation failed", errors: ["Invalid email"])
    #   result = task.result
    #
    #   ResultSerializer.call(result)
    #   # => {
    #   #   class: "ProcessOrderTask",
    #   #   type: "Task",
    #   #   index: 0,
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: "interrupted",
    #   #   status: "failed",
    #   #   outcome: "failed",
    #   #   metadata: { reason: "Validation failed", errors: ["Invalid email"] },
    #   #   runtime: 0.1
    #   # }
    #
    # @example Skipped result serialization
    #   task = ProcessOrderTask.new
    #   task.skip!(reason: "Order already processed")
    #   result = task.result
    #
    #   ResultSerializer.call(result)
    #   # => {
    #   #   class: "ProcessOrderTask",
    #   #   type: "Task",
    #   #   index: 0,
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: "interrupted",
    #   #   status: "skipped",
    #   #   outcome: "skipped",
    #   #   metadata: { reason: "Order already processed" },
    #   #   runtime: 0.05
    #   # }
    def call(result)
      TaskSerializer.call(result.task).tap do |hash|
        hash.merge!(
          state: result.state,
          status: result.status,
          outcome: result.outcome,
          metadata: result.metadata,
          runtime: result.runtime
        )

        if result.failed?
          STRIP_FAILURE.call(hash, result, :caused_failure)
          STRIP_FAILURE.call(hash, result, :threw_failure)
        end
      end
    end

  end
end

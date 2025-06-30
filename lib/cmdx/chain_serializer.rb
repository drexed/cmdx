# frozen_string_literal: true

module CMDx
  # Chain serialization utility for converting Chain objects to hash representations.
  #
  # The ChainSerializer module provides functionality to serialize Chain instances
  # into structured hash representations suitable for inspection, logging,
  # debugging, and data interchange. It creates comprehensive data structures
  # that include chain metadata and all associated task results.
  #
  # @example Basic chain serialization
  #   result = ProcessOrderTask.call(order_id: 123)
  #   chain = result.chain
  #
  #   ChainSerializer.call(chain)
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
  #   #       chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
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
  # @example Chain with multiple tasks
  #   class ComplexTask < CMDx::Task
  #     def call
  #       SubTask1.call(context)
  #       SubTask2.call(context)
  #     end
  #   end
  #
  #   result = ComplexTask.call
  #   chain = result.chain
  #
  #   ChainSerializer.call(chain)
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
  # @example Failed chain serialization
  #   failed_result = FailingTask.call
  #   failed_chain = failed_result.chain
  #
  #   ChainSerializer.call(failed_chain)
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
  # @see CMDx::Chain Chain execution context and result tracking
  # @see CMDx::ResultSerializer Individual result serialization
  # @see CMDx::ChainInspector Human-readable chain formatting
  module ChainSerializer

    module_function

    # Converts a Chain object to a hash representation.
    #
    # Serializes a Chain instance into a structured hash containing chain metadata
    # and all associated task results. The chain-level data is derived from the
    # first result in the collection, while all individual results are included
    # in their full serialized form.
    #
    # @param chain [CMDx::Chain] The chain object to serialize
    # @return [Hash] Structured hash representation of the chain and all results
    #
    # @example Simple chain serialization
    #   chain = SimpleTask.call.chain
    #   ChainSerializer.call(chain)
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
    #   #       chain_id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
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
    # @example Multi-task chain serialization
    #   class ParentTask < CMDx::Task
    #     def call
    #       ChildTask.call(context)
    #     end
    #   end
    #
    #   chain = ParentTask.call.chain
    #   ChainSerializer.call(chain)
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
    # @example Empty chain serialization
    #   empty_chain = Chain.new
    #   ChainSerializer.call(empty_chain)
    #   # => {
    #   #   id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
    #   #   state: nil,
    #   #   status: nil,
    #   #   outcome: nil,
    #   #   runtime: nil,
    #   #   results: []
    #   # }
    def call(chain)
      {
        id: chain.id,
        state: chain.state,
        status: chain.status,
        outcome: chain.outcome,
        runtime: chain.runtime,
        results: chain.results.map(&:to_h)
      }
    end

  end
end

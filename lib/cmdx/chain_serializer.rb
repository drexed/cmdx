# frozen_string_literal: true

module CMDx
  # Serialization module for converting chain objects to hash representation.
  #
  # ChainSerializer provides functionality to serialize chain objects into a
  # standardized hash format that includes essential metadata about the chain
  # execution including unique identification, execution state, status, outcome,
  # runtime, and all contained task results. The serialized format is commonly
  # used for debugging, logging, introspection, and data exchange throughout
  # the task execution pipeline.
  module ChainSerializer

    module_function

    # Serializes a chain object into a hash representation.
    #
    # Converts a chain instance into a standardized hash format containing
    # key metadata about the chain's execution context and all contained results.
    # The serialization includes information delegated from the first result in
    # the chain (state, status, outcome, runtime) along with the chain's unique
    # identifier and complete collection of task results converted to hashes.
    #
    # @param chain [CMDx::Chain] the chain object to serialize
    #
    # @return [Hash] a hash containing the chain's metadata and execution information
    # @option return [String] :id the unique identifier of the chain
    # @option return [String] :state the execution state delegated from first result
    # @option return [String] :status the execution status delegated from first result
    # @option return [String] :outcome the execution outcome delegated from first result
    # @option return [Float] :runtime the execution runtime in seconds delegated from first result
    # @option return [Array<Hash>] :results array of serialized result hashes from all tasks in the chain
    #
    # @raise [NoMethodError] if the chain doesn't respond to required methods (id, state, status, outcome, runtime, results)
    #
    # @example Serialize a workflow chain with multiple tasks
    #   workflow = DataProcessingWorkflow.call(input: "data")
    #   ChainSerializer.call(workflow.chain)
    #   #=> {
    #   #   id: "def456",
    #   #   state: "complete",
    #   #   status: "success",
    #   #   outcome: "success",
    #   #   runtime: 0.123,
    #   #   results: [
    #   #     { index: 0, class: "ValidateDataTask", status: "success", ... },
    #   #     { index: 1, class: "ProcessDataTask", status: "success", ... },
    #   #     { index: 2, class: "SaveDataTask", status: "success", ... }
    #   #   ]
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

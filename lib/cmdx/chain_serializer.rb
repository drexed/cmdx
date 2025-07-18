# frozen_string_literal: true

module CMDx
  # Serializes Chain objects into hash representations for external consumption.
  # Provides a consistent interface for converting chain execution data into
  # structured format suitable for logging, API responses, or persistence.
  module ChainSerializer

    module_function

    # Converts a chain object into a hash representation containing execution metadata.
    # Extracts key chain attributes and serializes all contained results for complete
    # execution state capture.
    #
    # @param chain [Chain] the chain instance to serialize
    #
    # @return [Hash] hash containing chain metadata and serialized results
    #
    # @raise [NoMethodError] if chain doesn't respond to required methods
    #
    # @example Serializing a workflow chain
    #   chain = UserWorkflow.call(user_id: 123)
    #   ChainSerializer.call(chain)
    #   # => {
    #   #   id: "abc123",
    #   #   state: :complete,
    #   #   status: :success,
    #   #   outcome: :good,
    #   #   runtime: 0.045,
    #   #   results: [...]
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

# frozen_string_literal: true

module CMDx
  # Provides serialization functionality for CMDx::Result objects,
  # converting them into structured hash representations suitable for
  # logging, storage, or transmission.
  module ResultSerializer

    # A proc that removes failure-related metadata from the hash representation
    # when the result hasn't actually failed in the specified way.
    # This prevents duplicate failure information from appearing in logs.
    STRIP_FAILURE = proc do |h, r, k|
      unless r.send(:"#{k}?")
        # Strip caused/threw failures since its the same info as the log line
        h[k] = r.send(k).to_h.except(:caused_failure, :threw_failure)
      end
    end.freeze

    module_function

    # Converts a Result object into a structured hash representation.
    # Combines task serialization data with result-specific information
    # including execution state, status, outcome, metadata, and runtime.
    #
    # @param result [CMDx::Result] the result object to serialize
    #
    # @return [Hash] a structured hash containing task information and result details
    #   including :state, :status, :outcome, :metadata, :runtime, and optionally
    #   :caused_failure and :threw_failure if the result failed
    #
    # @raise [NoMethodError] if result doesn't respond to expected methods
    # @raise [TypeError] if result.task is invalid for TaskSerializer
    #
    # @example Serializing a successful result
    #   result = task.call
    #   CMDx::ResultSerializer.call(result)
    #   #=> { index: 0, chain_id: "abc123", type: "Task", class: "MyTask",
    #   #     id: "def456", tags: [], state: "complete", status: "success",
    #   #     outcome: "good", metadata: {}, runtime: 0.05 }
    #
    # @example Serializing a failed result
    #   result = task.call
    #   CMDx::ResultSerializer.call(result)
    #   #=> { index: 0, chain_id: "abc123", type: "Task", class: "MyTask",
    #   #     id: "def456", tags: [], state: "interrupted", status: "failed",
    #   #     outcome: "bad", metadata: { error: "Something went wrong" },
    #   #     runtime: 0.02, caused_failure: {...}, threw_failure: {...} }
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

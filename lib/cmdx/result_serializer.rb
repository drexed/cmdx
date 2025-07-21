# frozen_string_literal: true

module CMDx
  # Result serialization module for converting result objects to hash format.
  #
  # This module provides functionality to serialize result objects into a
  # standardized hash representation that includes essential metadata about
  # the result such as task information, execution state, status, outcome,
  # metadata, and runtime. For failed results, it intelligently strips
  # redundant failure information to avoid duplication in serialized output.
  module ResultSerializer

    # Proc for stripping failure information from serialized results.
    # Removes caused_failure and threw_failure keys when the result doesn't
    # have the corresponding failure state, avoiding redundant information.
    STRIP_FAILURE = proc do |h, r, k|
      unless r.send(:"#{k}?")
        # Strip caused/threw failures since its the same info as the log line
        h[k] = r.send(k).to_h.except(:caused_failure, :threw_failure)
      end
    end.freeze

    module_function

    # Serializes a result object into a hash representation.
    #
    # Converts a result instance into a standardized hash format containing
    # task metadata and execution information. For failed results, applies
    # intelligent failure stripping to remove redundant caused_failure and
    # threw_failure information that would duplicate log output.
    #
    # @param result [CMDx::Result] the result object to serialize
    #
    # @return [Hash] a hash containing the result's metadata and execution information
    # @option return [Integer] :index the result's position index in the execution chain
    # @option return [String] :chain_id the unique identifier of the result's execution chain
    # @option return [String] :type the task type, either "Task" or "Workflow"
    # @option return [String] :class the full class name of the task
    # @option return [String] :id the unique identifier of the task instance
    # @option return [Array] :tags the tags associated with the task from cmd settings
    # @option return [Symbol] :state the execution state (:executing, :complete, :interrupted)
    # @option return [Symbol] :status the execution status (:success, :failed, :skipped)
    # @option return [Symbol] :outcome the execution outcome (:good, :bad)
    # @option return [Hash] :metadata additional metadata collected during execution
    # @option return [Float] :runtime the execution runtime in seconds
    # @option return [Hash] :caused_failure failure information if result caused a failure (stripped for non-failed results)
    # @option return [Hash] :threw_failure failure information if result threw a failure (stripped for non-failed results)
    #
    # @raise [NoMethodError] if the result doesn't respond to required methods
    #
    # @example Serialize a successful result
    #   task = SuccessfulTask.new(data: "test")
    #   ResultSerializer.call(result)
    #   #=> {
    #   #   index: 0,
    #   #   chain_id: "abc123",
    #   #   type: "Task",
    #   #   class: "SuccessfulTask",
    #   #   id: "def456",
    #   #   tags: [],
    #   #   state: :complete,
    #   #   status: :success,
    #   #   outcome: :good,
    #   #   metadata: {},
    #   #   runtime: 0.045
    #   # }
    #
    # @example Serialize a failed result with failure stripping
    #   task = FailingTask.call
    #   ResultSerializer.call(task.result)
    #   #=> {
    #   #   index: 1,
    #   #   chain_id: "xyz789",
    #   #   type: "Task",
    #   #   class: "FailingTask",
    #   #   id: "ghi012",
    #   #   tags: [],
    #   #   state: :interrupted,
    #   #   status: :failed,
    #   #   outcome: :bad,
    #   #   metadata: { reason: "Database connection failed" },
    #   #   runtime: 0.012,
    #   #   caused_failure: { message: "Task failed", ... },
    #   #   threw_failure: { message: "Validation error", ... },
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

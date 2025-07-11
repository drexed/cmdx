# frozen_string_literal: true

module CMDx
  # Serializes Task objects into hash representations for external consumption.
  # Provides a consistent interface for converting task execution data into
  # structured format suitable for logging, API responses, or persistence.
  module TaskSerializer

    module_function

    # Converts a task object into a hash representation containing task metadata.
    # Extracts key task attributes including execution index, chain association,
    # type classification, and associated tags for complete task identification.
    #
    # @param task [Task] the task instance to serialize
    #
    # @return [Hash] hash containing task metadata and execution details
    #
    # @raise [NoMethodError] if task doesn't respond to required methods
    #
    # @example Serializing a task
    #   task = UserRegistrationTask.call(email: "user@example.com")
    #   TaskSerializer.call(task)
    #   # => {
    #   #   index: 0,
    #   #   chain_id: "abc123",
    #   #   type: "Task",
    #   #   class: "UserRegistrationTask",
    #   #   id: "def456",
    #   #   tags: [:authentication, :user_management]
    #   # }
    def call(task)
      {
        index: task.result.index,
        chain_id: task.chain.id,
        type: task.is_a?(Workflow) ? "Workflow" : "Task",
        class: task.class.name,
        id: task.id,
        tags: task.cmd_setting(:tags)
      }
    end

  end
end

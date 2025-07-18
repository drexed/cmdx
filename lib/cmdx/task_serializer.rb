# frozen_string_literal: true

module CMDx
  # Task serialization module for converting task objects to hash format.
  #
  # TaskSerializer provides functionality to serialize task objects into a
  # standardized hash representation that includes essential metadata about
  # the task such as its index, chain ID, type, class, ID, and tags. The
  # serialized format is commonly used for debugging, logging, and introspection
  # purposes throughout the task execution pipeline.
  module TaskSerializer

    module_function

    # Serializes a task object into a hash representation.
    #
    # Converts a task instance into a standardized hash format containing
    # key metadata about the task's execution context and classification.
    # The serialization includes information from the task's result, chain,
    # and command settings to provide comprehensive task identification.
    #
    # @param task [CMDx::Task, CMDx::Workflow] the task or workflow object to serialize
    #
    # @return [Hash] a hash containing the task's metadata
    # @option return [Integer] :index the task's position index in the execution chain
    # @option return [String] :chain_id the unique identifier of the task's execution chain
    # @option return [String] :type the task type, either "Task" or "Workflow"
    # @option return [String] :class the full class name of the task
    # @option return [String] :id the unique identifier of the task instance
    # @option return [Array] :tags the tags associated with the task from cmd settings
    #
    # @raise [NoMethodError] if the task doesn't respond to required methods
    #
    # @example Serialize a basic task
    #   task = ProcessDataTask.new
    #   TaskSerializer.call(task)
    #   # => {
    #   #   index: 0,
    #   #   chain_id: "abc123",
    #   #   type: "Task",
    #   #   class: "ProcessDataTask",
    #   #   id: "def456",
    #   #   tags: []
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

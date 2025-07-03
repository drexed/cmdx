# frozen_string_literal: true

module CMDx
  ##
  # TaskSerializer converts task instances into hash representations for
  # logging, debugging, and serialization purposes. It extracts key metadata
  # about the task execution context and identification.
  #
  # The serialized format includes:
  # - Execution index within the chain
  # - Chain identifier for grouping related tasks
  # - Task type (Task vs Workflow)
  # - Class name for identification
  # - Unique task instance ID
  # - Associated tags for categorization
  #
  # @example Basic serialization
  #   class ProcessOrderTask < CMDx::Task
  #     task_settings!(tags: [:order, :payment])
  #   end
  #
  #   task = ProcessOrderTask.call(order_id: 123)
  #   TaskSerializer.call(task)
  #   #=> {
  #   #     index: 1,
  #   #     chain_id: "abc123...",
  #   #     type: "Task",
  #   #     class: "ProcessOrderTask",
  #   #     id: "def456...",
  #   #     tags: [:order, :payment]
  #   #   }
  #
  # @example Workflow serialization
  #   class OrderProcessingWorkflow < CMDx::Workflow
  #     task_settings!(tags: [:workflow, :orders])
  #   end
  #
  #   workflow = OrderProcessingWorkflow.call(orders: [...])
  #   TaskSerializer.call(workflow)
  #   #=> {
  #   #     index: 1,
  #   #     chain_id: "abc123...",
  #   #     type: "Workflow",
  #   #     class: "OrderProcessingWorkflow",
  #   #     id: "ghi789...",
  #   #     tags: [:workflow, :orders]
  #   #   }
  #
  # @see Task Task class for execution context
  # @see Workflow Workflow class for multi-task execution
  # @see Chain Chain class for execution grouping
  # @since 1.0.0
  module TaskSerializer

    module_function

    ##
    # Serializes a task instance into a hash representation containing
    # essential metadata for identification and tracking.
    #
    # @param task [Task, Workflow] the task instance to serialize
    # @return [Hash] serialized task data with the following keys:
    #   - :index [Integer] position within the execution chain
    #   - :chain_id [String] identifier of the containing chain
    #   - :type [String] "Task" or "Workflow" based on instance type
    #   - :class [String] class name of the task
    #   - :id [String] unique identifier for this task instance
    #   - :tags [Array] array of tags associated with the task
    #
    # @example Serializing a task
    #   task = MyTask.call(param: "value")
    #   data = TaskSerializer.call(task)
    #   data[:class] #=> "MyTask"
    #   data[:type] #=> "Task"
    #   data[:id] #=> "550e8400-e29b-41d4-a716-446655440000"
    #
    # @example Using serialized data for logging
    #   task_data = TaskSerializer.call(task)
    #   logger.info("Task executed", task_data)
    def call(task)
      {
        index: task.result.index,
        chain_id: task.chain.id,
        type: task.is_a?(Workflow) ? "Workflow" : "Task",
        class: task.class.name,
        id: task.id,
        tags: task.task_setting(:tags)
      }
    end

  end
end

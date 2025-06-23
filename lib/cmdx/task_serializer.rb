# frozen_string_literal: true

module CMDx
  ##
  # TaskSerializer converts task instances into hash representations for
  # logging, debugging, and serialization purposes. It extracts key metadata
  # about the task execution context and identification.
  #
  # The serialized format includes:
  # - Execution index within the run
  # - Run identifier for grouping related tasks
  # - Task type (Task vs Batch)
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
  #   #     run_id: "abc123...",
  #   #     type: "Task",
  #   #     class: "ProcessOrderTask",
  #   #     id: "def456...",
  #   #     tags: [:order, :payment]
  #   #   }
  #
  # @example Batch serialization
  #   class OrderProcessingBatch < CMDx::Batch
  #     task_settings!(tags: [:batch, :orders])
  #   end
  #
  #   batch = OrderProcessingBatch.call(orders: [...])
  #   TaskSerializer.call(batch)
  #   #=> {
  #   #     index: 1,
  #   #     run_id: "abc123...",
  #   #     type: "Batch",
  #   #     class: "OrderProcessingBatch",
  #   #     id: "ghi789...",
  #   #     tags: [:batch, :orders]
  #   #   }
  #
  # @see Task Task class for execution context
  # @see Batch Batch class for multi-task execution
  # @see Run Run class for execution grouping
  # @since 0.6.0
  module TaskSerializer

    module_function

    ##
    # Serializes a task instance into a hash representation containing
    # essential metadata for identification and tracking.
    #
    # @param task [Task, Batch] the task instance to serialize
    # @return [Hash] serialized task data with the following keys:
    #   - :index [Integer] position within the execution run
    #   - :run_id [String] identifier of the containing run
    #   - :type [String] "Task" or "Batch" based on instance type
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
        run_id: task.run.id,
        type: task.is_a?(Batch) ? "Batch" : "Task",
        class: task.class.name,
        id: task.id,
        tags: task.task_setting(:tags)
      }
    end

  end
end

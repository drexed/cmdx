# frozen_string_literal: true

module CMDx
  # Result-specific logging module for task execution outcomes.
  #
  # The ResultLogger module provides specialized logging functionality for
  # CMDx task results. It automatically maps result statuses to appropriate
  # log severity levels and handles conditional logging based on logger
  # availability and configuration.
  #
  # @example Successful task result logging
  #   task = ProcessOrderTask.call(order_id: 123)
  #   ResultLogger.call(task.result)
  #   # Logs at INFO level: "ProcessOrderTask completed successfully"
  #
  # @example Failed task result logging
  #   task = ProcessOrderTask.call(invalid_params)
  #   ResultLogger.call(task.result)
  #   # Logs at ERROR level: "ProcessOrderTask failed with errors"
  #
  # @example Skipped task result logging
  #   task = ProcessOrderTask.new
  #   task.skip!("Order already processed")
  #   ResultLogger.call(task.result)
  #   # Logs at WARN level: "ProcessOrderTask was skipped"
  #
  # @example Integration with task execution
  #   class ProcessOrderTask < CMDx::Task
  #     def call
  #       # Task logic here
  #     end
  #
  #     # ResultLogger.call is automatically invoked after task execution
  #   end
  #
  # @see CMDx::Result Result object status and state management
  # @see CMDx::Logger Logger configuration and setup
  # @see CMDx::Task Task execution and result handling
  module ResultLogger

    # Mapping of result statuses to corresponding log severity levels.
    #
    # Maps CMDx result status constants to Ruby Logger severity levels
    # to ensure appropriate logging levels for different task outcomes.
    STATUS_TO_SEVERITY = {
      Result::SUCCESS => :info,   # Successful task completion
      Result::SKIPPED => :warn,   # Task was skipped
      Result::FAILED => :error    # Task execution failed
    }.freeze

    module_function

    # Logs a task result at the appropriate severity level.
    #
    # Determines the appropriate log severity based on the result status
    # and logs the result object using the task's configured logger.
    # Does nothing if no logger is configured for the task.
    #
    # @param result [CMDx::Result] The task result to log
    # @return [void]
    #
    # @example Logging a successful result
    #   task = ProcessOrderTask.call(order_id: 123)
    #   ResultLogger.call(task.result)
    #   # Logs at INFO level with result details
    #
    # @example Logging a failed result
    #   task = ProcessOrderTask.new
    #   task.fail!("Invalid order ID")
    #   ResultLogger.call(task.result)
    #   # Logs at ERROR level with failure details
    #
    # @example Logging a skipped result
    #   task = ProcessOrderTask.new
    #   task.skip!("Order already processed")
    #   ResultLogger.call(task.result)
    #   # Logs at WARN level with skip reason
    #
    # @example No logger configured
    #   class SimpleTask < CMDx::Task
    #     # No logger setting
    #   end
    #
    #   task = SimpleTask.call
    #   ResultLogger.call(task.result)  # Does nothing - no logger available
    #
    # @example Custom logger configuration
    #   class MyTask < CMDx::Task
    #     task_settings!(
    #       logger: Logger.new(STDOUT),
    #       log_formatter: CMDx::LogFormatters::Json.new
    #     )
    #   end
    #
    #   task = MyTask.call
    #   ResultLogger.call(task.result)  # Logs in JSON format to STDOUT
    #
    # @note This method is typically called automatically by the CMDx framework
    #   after task execution completes, ensuring that all task results are
    #   properly logged according to their outcome.
    def call(result)
      logger = result.task.send(:logger)
      return if logger.nil?

      severity = STATUS_TO_SEVERITY[result.status]

      logger.with_level(severity) do
        logger.send(severity) { result }
      end
    end

  end
end

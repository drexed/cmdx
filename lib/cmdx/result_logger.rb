# frozen_string_literal: true

module CMDx
  # Logger utilities for task execution results.
  #
  # This module provides functionality to log task execution results with appropriate
  # severity levels based on the result status. It automatically maps result statuses
  # to corresponding log levels and delegates to the task's configured logger.
  module ResultLogger

    STATUS_TO_SEVERITY = {
      Result::SUCCESS => :info,   # Successful task completion
      Result::SKIPPED => :warn,   # Task was skipped
      Result::FAILED => :error    # Task execution failed
    }.freeze

    module_function

    # Logs the task execution result with appropriate severity level.
    #
    # This method retrieves the logger from the task and logs the result using
    # the severity level mapped from the result's status. If no logger is configured
    # for the task, the method returns early without logging.
    #
    # @param result [Result] the task execution result to log
    #
    # @return [void]
    #
    # @example Log a successful task result
    #   result = task.process
    #   CMDx::ResultLogger.call(result)
    #   # => logs at info level: "Task completed successfully"
    #
    # @example Log a failed task result
    #   result = failing_task.process
    #   CMDx::ResultLogger.call(result)
    #   # => logs at error level: "Task failed with error"
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

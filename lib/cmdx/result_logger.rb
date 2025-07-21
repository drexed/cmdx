# frozen_string_literal: true

module CMDx
  # Logger utilities for task execution results.
  #
  # This module provides functionality to log task execution results with
  # appropriate severity levels based on the result status. It automatically
  # determines the correct log level (info, warn, error) based on whether
  # the task succeeded, was skipped, or failed, and delegates to the task's
  # configured logger instance.
  module ResultLogger

    STATUS_TO_SEVERITY = {
      Result::SUCCESS => :info,   # Successful task completion
      Result::SKIPPED => :warn,   # Task was skipped
      Result::FAILED => :error    # Task execution failed
    }.freeze

    module_function

    # Logs a task execution result with the appropriate severity level.
    #
    # Retrieves the logger from the task instance and logs the result object
    # using the severity level determined by the result's status. If no logger
    # is configured for the task, the method returns early without logging.
    # The logger level is temporarily set to match the severity to ensure
    # the message is captured regardless of current log level configuration.
    #
    # @param result [CMDx::Result] the task execution result to log
    #
    # @return [void]
    #
    # @example Log a successful task result
    #   task = ProcessDataTask.call(data: "input")
    #   ResultLogger.call(task.result)
    #   # Logs at :info level: "Result: ProcessDataTask completed successfully"
    #
    # @example Log a failed task result
    #   task = ValidateDataTask.call(data: "invalid")
    #   ResultLogger.call(task.result)
    #   # Logs at :error level: "Result: ValidateDataTask failed with error"
    #
    # @example Log a skipped task result
    #   task = ConditionalTask.call(condition: false)
    #   ResultLogger.call(task.result)
    #   # Logs at :warn level: "Result: ConditionalTask was skipped"
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

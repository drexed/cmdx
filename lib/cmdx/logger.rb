# frozen_string_literal: true

module CMDx
  # Logger configuration and retrieval utilities for task execution.
  #
  # This module provides functionality to configure and retrieve logger instances
  # for task execution, applying task-specific settings such as formatter, level,
  # and program name when available.
  module Logger

    module_function

    # Configures and returns a logger instance for the given task.
    #
    # This method retrieves the logger from task settings and applies any
    # available configuration options including formatter, level, and program name.
    # The task itself is set as the logger's program name for identification.
    #
    # @param task [Task] the task instance to configure logging for
    #
    # @return [Logger, nil] the configured logger instance or nil if no logger is set
    #
    # @example Configure logger for a task
    #   logger = CMDx::Logger.call(task)
    #   logger.info("Task started")
    #
    # @example Logger with custom formatter
    #   task.set_task_setting(:log_formatter, custom_formatter)
    #   logger = CMDx::Logger.call(task)
    #   logger.debug("Debug message")
    def call(task)
      logger = task.task_setting(:logger)

      unless logger.nil?
        logger.formatter = task.task_setting(:log_formatter) if task.task_setting?(:log_formatter)
        logger.level     = task.task_setting(:log_level) if task.task_setting?(:log_level)
        logger.progname  = task
      end

      logger
    end

  end
end

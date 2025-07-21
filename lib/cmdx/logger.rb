# frozen_string_literal: true

module CMDx
  # Logger management module for configuring and retrieving task-specific loggers.
  #
  # This module provides functionality to extract and configure logger instances
  # from task settings, applying formatter, level, and progname configurations
  # when available. It serves as a central point for logger setup during task execution.
  module Logger

    module_function

    # Configures and returns a logger instance for the given task.
    #
    # Extracts the logger from task settings and applies additional configuration
    # such as formatter, log level, and progname if they are specified in the
    # task's command settings. The progname is set to the task instance itself
    # for better log traceability.
    #
    # @param task [Task] the task instance containing logger configuration settings
    #
    # @return [Logger, nil] the configured logger instance, or nil if no logger is set
    #
    # @example Configure logger for a task
    #   class MyTask < CMDx::Task
    #     cmd setting!(
    #       logger: Logger.new($stdout),
    #       log_level: Logger::DEBUG,
    #       log_formatter: CMDx::LogFormatters::JSON.new
    #     )
    #   end
    #
    #   task = MyTask.call
    #   logger = CMDx::Logger.call(task)
    #   #=> Returns configured logger with DEBUG level and JSON formatter
    def call(task)
      logger = task.cmd_setting(:logger)

      unless logger.nil?
        logger.formatter = task.cmd_setting(:log_formatter) if task.cmd_setting?(:log_formatter)
        logger.level     = task.cmd_setting(:log_level) if task.cmd_setting?(:log_level)
        logger.progname  = task
      end

      logger
    end

  end
end

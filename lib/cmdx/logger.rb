# frozen_string_literal: true

module CMDx
  module Logger

    module_function

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

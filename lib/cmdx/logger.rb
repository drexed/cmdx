# frozen_string_literal: true

module CMDx
  module Logger

    module_function

    def call(task)
      logger           = task.task_setting(:logger)
      logger.formatter = task.task_setting(:log_formatter) if task.task_setting?(:log_formatter)
      logger.level     = task.task_setting(:log_level) if task.task_setting?(:log_level)
      logger
    end

  end
end

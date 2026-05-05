# frozen_string_literal: true

module CMDx
  # Returns a logger tailored to a task's settings. If the task overrides
  # `log_level` or `log_formatter`, the base logger is `dup`'d so those
  # overrides don't leak into sibling tasks sharing the same global logger.
  module LoggerProxy

    extend self

    # @param task [Task]
    # @return [Logger] a logger configured with the task's level/formatter
    def logger(task)
      settings  = task.class.settings
      logger    = settings.logger
      level     = settings.log_level
      formatter = settings.log_formatter

      change_level     = level && level != logger.level
      change_formatter = formatter && !logger.formatter.equal?(formatter)
      return logger unless change_level || change_formatter

      logger = logger.dup
      logger.level     = level     if change_level
      logger.formatter = formatter if change_formatter
      logger
    end

  end
end

# frozen_string_literal: true

module CMDx
  # Task deprecation system for CMDx tasks.
  #
  # This module provides a centralized system for handling task deprecation
  # warnings and errors. It supports multiple deprecation modes including
  # raising exceptions, logging warnings, or issuing Ruby warnings based
  # on task configuration settings.
  module TaskDeprecator

    module_function

    # Processes task deprecation based on the task's deprecated setting.
    #
    # @param task [CMDx::Task] the task instance to check for deprecation
    # @return [void]
    # @raise [DeprecationError] when task's deprecated setting is :error
    #
    # @example Handle task with raise deprecation
    #   class MyTask < CMDx::Task
    #     cmd_setting!(deprecated: :error)
    #   end
    #   task = MyTask.new
    #   TaskDeprecator.call(task) # raises DeprecationError
    #
    # @example Handle task with log deprecation
    #   class MyTask < CMDx::Task
    #     cmd_setting!(deprecated: :log)
    #   end
    #   task = MyTask.new
    #   TaskDeprecator.call(task) # logs warning via task.logger
    #
    # @example Handle task with warn deprecation
    #   class MyTask < CMDx::Task
    #     cmd_setting!(deprecated: :warning)
    #   end
    #   task = MyTask.new
    #   TaskDeprecator.call(task) # issues Ruby warning
    def call(task)
      type = task.cmd_setting(:deprecated)

      case type
      when :error
        raise DeprecationError, "#{task.class.name} usage prohibited"
      when :log, true
        task.logger.warn { "DEPRECATED: migrate to replacement or discontinue use" }
      when :warning
        warn("[#{task.class.name}] DEPRECATED: migrate to replacement or discontinue use", category: :deprecated)
      when nil, false
        # Do nothing
      else
        raise UnknownDeprecationError, "unknown deprecation type #{type}"
      end
    end

  end
end

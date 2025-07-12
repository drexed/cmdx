# frozen_string_literal: true

module CMDx
  # Handles deprecation checking for CMDx tasks.
  #
  # This module provides functionality to check if a task is marked as deprecated
  # and raise appropriate errors when deprecated tasks are instantiated. It integrates
  # with the task lifecycle to prevent usage of deprecated functionality.
  module TaskDeprecator

    module_function

    # Checks if a task is deprecated and handles deprecation warnings or errors.
    # Raises a DeprecationError if the task is marked as deprecated with a truthy value,
    # otherwise logs a warning if the deprecated setting exists but is falsy.
    #
    # @param task [Task] the task instance to check for deprecation
    #
    # @return [void]
    #
    # @raise [DeprecationError] if the task is marked as deprecated
    #
    # @example With a deprecated task
    #   class ObsoleteTask < CMDx::Task
    #     cmd_setting :deprecated, true
    #   end
    #
    #   task = ObsoleteTask.new
    #   CMDx::TaskDeprecator.call(task)
    #   # => raises DeprecationError: "ObsoleteTask is deprecated"
    #
    # @example With a task marked for future deprecation
    #   class LegacyTask < CMDx::Task
    #     cmd_setting :deprecated, false
    #   end
    #
    #   task = LegacyTask.new
    #   CMDx::TaskDeprecator.call(task)
    #   # => logs warning: "LegacyTask will be deprecated. Find a replacement or stop usage"
    def call(task)
      return unless task.cmd_setting?(:deprecated)

      raise(DeprecationError, "#{task.class.name} is deprecated") if task.cmd_setting(:deprecated)

      msg = "#{task.class.name} will be deprecated. Find a replacement or stop usage"
      warn(msg, category: :deprecated)
      task.logger.warn { msg }
    end

  end
end

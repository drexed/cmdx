# frozen_string_literal: true

module CMDx
  # Handles deprecation checking for CMDx tasks.
  #
  # This module provides functionality to check if a task is marked as deprecated
  # and raise appropriate errors when deprecated tasks are instantiated. It integrates
  # with the task lifecycle to prevent usage of deprecated functionality.
  module TaskDeprecator

    module_function

    # Checks deprecation status of a task and handles it according to the configured behavior.
    #
    # This method examines the task's deprecation setting and takes appropriate action:
    # - :raise - raises DeprecationError to prevent task execution
    # - :warn - issues Ruby deprecation warning
    # - :log or true - logs deprecation warning
    # - nil or false - allows task execution without warnings
    #
    # @param task [Task] the task instance to check for deprecation
    #
    # @return [void]
    #
    # @raise [DeprecationError] when task is marked with deprecated: :raise
    #
    # @example Task with raise deprecation setting
    #   class MyTask < CMDx::Task
    #     cmd_settings! deprecated: :raise
    #   end
    #   CMDx::TaskDeprecator.call(MyTask.new) # raises DeprecationError
    #
    # @example Task with warn deprecation setting
    #   class MyTask < CMDx::Task
    #     cmd_settings! deprecated: :warn
    #   end
    #   CMDx::TaskDeprecator.call(MyTask.new) # issues warnings
    #
    # @example Task with a proc deprecation setting
    #   class MyTask < CMDx::Task
    #     cmd_settings! deprecated: -> { Time.now.year > 2025 ? :raise : :warn }
    #   end
    #   CMDx::TaskDeprecator.call(MyTask.new) # issues warnings
    #
    # @example Task with no deprecation setting
    #   class MyTask < CMDx::Task
    #   end
    #   CMDx::TaskDeprecator.call(MyTask.new) # no action taken
    def call(task)
      case task.cmd_setting(:deprecated)
      when :raise
        raise(DeprecationError, "#{task.class.name} usage prohibited")
      when :log, true
        task.logger.warn { "DEPRECATED: migrate to replacement or discontinue use" }
      when :warn
        warn("[#{task.class.name}] DEPRECATED: migrate to replacement or discontinue use", category: :deprecated)
      end
    end

  end
end

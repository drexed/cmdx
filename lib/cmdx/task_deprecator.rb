# frozen_string_literal: true

module CMDx
  # Handles deprecation checking for CMDx tasks.
  #
  # This module provides functionality to check if a task is marked as deprecated
  # and raise appropriate errors when deprecated tasks are instantiated. It integrates
  # with the task lifecycle to prevent usage of deprecated functionality.
  module TaskDeprecator

    module_function

    # Checks if a task is deprecated and raises an error if so.
    #
    # This method examines the task's cmd_setting for the :deprecated flag and
    # raises a DeprecationError if the task is marked as deprecated. This prevents
    # the instantiation and usage of deprecated tasks.
    #
    # @param task [CMDx::Task] the task instance to check for deprecation
    #
    # @return [void] returns nothing if the task is not deprecated
    #
    # @raise [DeprecationError] when the task is marked as deprecated
    #
    # @example Check a non-deprecated task
    #   TaskDeprecator.call(my_task) # no error raised
    #
    # @example Check a deprecated task
    #   deprecated_task.cmd_settings!(deprecated: true)
    #   TaskDeprecator.call(deprecated_task) # raises DeprecationError
    def call(task)
      return unless task.cmd_setting?(:deprecated)

      msg = "#{task.class.name} is deprecated"
      raise(DeprecationError, msg) if task.cmd_setting(:deprecated)

      warn(msg, category: :deprecated)
      task.logger.warn { msg }
    end

  end
end

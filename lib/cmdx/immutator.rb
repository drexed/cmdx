# frozen_string_literal: true

module CMDx
  # Provides object immutability functionality for tasks and their associated objects.
  #
  # This module freezes task objects and their related components after execution
  # to prevent unintended modifications. It supports conditional freezing through
  # environment variable configuration, allowing developers to disable immutability
  # during testing scenarios where object stubbing is required.
  module Immutator

    module_function

    # Freezes a task and its associated objects to prevent further modification.
    #
    # This method makes the task, its result, and related objects immutable after
    # execution. If the task result index is zero (indicating the first task in a chain),
    # it also freezes the context and chain objects. The freezing behavior can be
    # disabled via the SKIP_CMDX_FREEZING environment variable for testing purposes.
    #
    # @param task [CMDx::Task] the task instance to freeze along with its associated objects
    #
    # @return [void] returns nil when freezing is skipped, otherwise no meaningful return value
    #
    # @example Freeze a task after execution
    #   task = MyTask.call(user_id: 123)
    #   CMDx::Immutator.call(task)
    #   task.frozen? #=> true
    #   task.result.frozen? #=> true
    #
    # @example Skip freezing during testing
    #   ENV["SKIP_CMDX_FREEZING"] = "true"
    #   task = MyTask.call(user_id: 123)
    #   CMDx::Immutator.call(task)
    #   task.frozen? #=> false
    def call(task)
      # Stubbing on frozen objects is not allowed
      skip_freezing = ENV.fetch("SKIP_CMDX_FREEZING", false)
      return if Coercions::Boolean.call(skip_freezing)

      task.freeze
      task.result.freeze
      return unless task.result.index.zero?

      task.context.freeze
      task.chain.freeze

      Chain.clear
    end

  end
end

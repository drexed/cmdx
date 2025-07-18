# frozen_string_literal: true

module CMDx
  # Freezes task objects after execution to ensure immutability.
  #
  # This module provides the final step in the task lifecycle by freezing
  # task instances and their associated objects to prevent further modification.
  # The freezing behavior can be controlled via environment variables and
  # is conditionally applied based on the task's position in the execution chain.
  module Immutator

    module_function

    # Freezes task objects after execution to make them immutable.
    #
    # Always freezes the task and its result. For the first task in a chain
    # (index 0), also freezes the context and chain, then clears the chain.
    # Freezing can be skipped entirely by setting the SKIP_CMDX_FREEZING
    # environment variable to a truthy value.
    #
    # @param task [Task] the task instance to freeze after execution
    #
    # @return [nil] always returns nil
    #
    # @raise [StandardError] if any freeze operation fails
    #
    # @example Freeze a completed task
    #   task = MyTask.new(user_id: 123)
    #   task.process
    #   CMDx::Immutator.call(task)
    #   task.frozen? #=> true
    #
    # @example Skip freezing for testing
    #   ENV["SKIP_CMDX_FREEZING"] = "1"
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

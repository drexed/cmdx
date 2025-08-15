# frozen_string_literal: true

module CMDx
  # Provides freezing functionality for CMDx tasks and their associated objects.
  #
  # The Freezer module is responsible for making task objects immutable after execution
  # to prevent accidental modifications and ensure data integrity. It can be disabled
  # via environment variable for testing or debugging purposes.
  module Freezer

    extend self

    # Freezes a task and its associated objects to prevent modifications.
    #
    # This method makes the task, result, context, and chain immutable after execution.
    # Freezing can be skipped by setting the SKIP_CMDX_FREEZING environment variable.
    #
    # @param task [Task] The task instance to freeze
    # @option ENV["SKIP_CMDX_FREEZING"] [String, Boolean] Set to "true" or true to skip freezing
    #
    # @return [void]
    #
    # @raise [RuntimeError] If attempting to stub on frozen objects
    #
    # @example Freeze a completed task
    #   task = MyTask.new
    #   task.execute
    #   CMDx::Freezer.immute(task)
    #   # task, result, context, and chain are now frozen
    # @example Skip freezing for testing
    #   ENV["SKIP_CMDX_FREEZING"] = "true"
    #   CMDx::Freezer.immute(task)
    #   # No freezing occurs
    def immute(task)
      # Stubbing on frozen objects is not allowed
      skip_freezing = ENV.fetch("SKIP_CMDX_FREEZING", false)
      return if Coercions::Boolean.call(skip_freezing)

      task.freeze
      task.result.freeze

      # Freezing the context and chain can only be done
      # once the outer-most task has completed.
      return unless task.result.index.zero?

      task.context.freeze
      task.chain.freeze

      Chain.clear
    end

  end
end

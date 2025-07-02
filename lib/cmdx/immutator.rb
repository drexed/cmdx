# frozen_string_literal: true

module CMDx
  ##
  # Immutator provides task finalization by freezing objects to prevent mutation
  # after task execution is complete. This ensures task immutability and prevents
  # accidental side effects or modifications to completed task instances.
  #
  # The Immutator is automatically called during the task termination phase as part
  # of the execution lifecycle. It freezes the task instance, its result, and
  # associated objects to maintain data integrity and enforce the single-use pattern
  # of CMDx tasks.
  #
  # ## Freezing Strategy
  #
  # The Immutator employs a selective freezing strategy:
  # 1. **Task Instance**: Always frozen to prevent method calls and modifications
  # 2. **Result Object**: Always frozen to preserve execution outcome
  # 3. **Context Object**: Frozen only for the first task in a chain (index 0)
  # 4. **Chain Object**: Frozen only for the first task in a chain (index 0)
  #
  # This selective approach allows subsequent tasks in a batch or chain to continue
  # using the shared context and chain objects while ensuring completed tasks remain
  # immutable.
  #
  # ## Test Environment Handling
  #
  # In test environments (Rails or Rack), freezing is automatically disabled to
  # prevent conflicts with test frameworks that may need to stub or mock frozen
  # objects. This ensures smooth testing without compromising the immutability
  # guarantees in production environments.
  #
  # @example Task execution with automatic freezing
  #   class ProcessOrderTask < CMDx::Task
  #     required :order_id, type: :integer
  #
  #     def call
  #       context.order = Order.find(order_id)
  #       context.order.process!
  #     end
  #   end
  #
  #   result = ProcessOrderTask.call(order_id: 123)
  #   result.frozen?         #=> true
  #   result.task.frozen?    #=> true
  #   result.context.frozen? #=> true (if first task in chain)
  #
  # @example Attempting to modify frozen task (will raise error)
  #   result = ProcessOrderTask.call(order_id: 123)
  #   result.context.new_field = "value"  #=> FrozenError
  #   result.task.call                    #=> FrozenError
  #
  # @example Batch execution with selective freezing
  #   class OrderBatch < CMDx::Batch
  #     def call
  #       ProcessOrderTask.call(context)
  #       SendEmailTask.call(context)
  #     end
  #   end
  #
  #   result = OrderBatch.call(order_id: 123)
  #   # First task freezes context and chain
  #   # Second task can still use unfrozen context for execution
  #   # But both task instances are individually frozen
  #
  # @example Test environment behavior
  #   # In test environment (SKIP_CMDX_FREEZING=1)
  #   result = ProcessOrderTask.call(order_id: 123)
  #   result.frozen?      #=> false (freezing disabled)
  #   result.task.frozen? #=> false (allows stubbing/mocking)
  #
  # @see Task Task execution lifecycle
  # @see Result Result object that gets frozen
  # @see Context Context object that may get frozen
  # @see Chain Chain object that may get frozen
  # @since 1.0.0
  module Immutator

    module_function

    ##
    # Freezes task-related objects to ensure immutability after execution.
    # This method is called automatically during task termination and implements
    # a selective freezing strategy based on task position within a chain.
    #
    # The freezing process:
    # 1. Checks if running in test environment and skips freezing if so
    # 2. Always freezes the task instance and its result
    # 3. Freezes context and chain only for the first task (index 0) in a chain
    #
    # This selective approach ensures that:
    # - Completed tasks cannot be modified or re-executed
    # - Results remain immutable and trustworthy
    # - Shared objects (context/chain) remain available for subsequent tasks
    # - Test environments can continue to function with mocking/stubbing
    #
    # @param task [Task] the task instance to freeze along with its associated objects
    # @return [void]
    #
    # @example First task in chain (freezes everything)
    #   task = ProcessOrderTask.call(order_id: 123)
    #   # task.result.index == 0
    #   Immutator.call(task)
    #   # Freezes: task, result, context, chain
    #
    # @example Subsequent task in chain (selective freezing)
    #   # After first task has run
    #   task = SendEmailTask.call(context)
    #   # task.result.index == 1
    #   Immutator.call(task)
    #   # Freezes: task, result (context and chain remain unfrozen)
    #
    # @example Test environment (no freezing)
    #   ENV["RAILS_ENV"] = "test"
    #   task = ProcessOrderTask.call(order_id: 123)
    #   Immutator.call(task)
    #   # No objects are frozen, allows test stubbing
    #
    # @note This method is automatically called by the task execution framework
    #   and should not typically be called directly by user code.
    #
    # @note Freezing is skipped entirely in test environments to prevent conflicts
    #   with test frameworks that need to stub or mock objects.
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

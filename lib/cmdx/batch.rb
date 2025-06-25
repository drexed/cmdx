# frozen_string_literal: true

module CMDx
  ##
  # Orchestrates sequential execution of multiple tasks in a linear pipeline.
  # Batch provides a declarative DSL for composing complex business workflows
  # from individual task components, with support for conditional execution,
  # context passing, and configurable halt behavior.
  #
  # Batches inherit from Task, gaining all task capabilities including hooks,
  # parameter validation, result tracking, and configuration. The key difference
  # is that batches coordinate other tasks rather than implementing business logic directly.
  #
  #
  # ## Execution Flow
  #
  # 1. **Group Evaluation**: Check if group conditions (`:if`/`:unless`) are met
  # 2. **Task Execution**: Run each task in the group sequentially
  # 3. **Result Checking**: Evaluate task result against halt conditions
  # 4. **Halt Decision**: Stop execution if halt conditions are met, otherwise continue
  # 5. **Context Propagation**: Pass updated context to next task/group
  #
  # ## Halt Behavior
  #
  # By default, batches halt on `FAILED` status but continue on `SKIPPED`.
  # This reflects the philosophy that skipped tasks are bypass mechanisms,
  # not execution blockers. Halt behavior can be customized at class or group level.
  #
  # @example Basic batch definition
  #   class ProcessOrderBatch < CMDx::Batch
  #     process ValidateOrderTask
  #     process CalculateTaxTask
  #     process ChargePaymentTask
  #     process FulfillOrderTask
  #   end
  #
  # @example Multiple task declarations
  #   class NotificationBatch < CMDx::Batch
  #     # Single task
  #     process PrepareNotificationTask
  #
  #     # Multiple tasks in one declaration
  #     process SendEmailTask, SendSmsTask, SendPushTask
  #   end
  #
  # @example Conditional execution
  #   class ConditionalBatch < CMDx::Batch
  #     process AlwaysRunTask
  #
  #     # Conditional execution with proc
  #     process PremiumFeatureTask, if: proc { context.user.premium? }
  #
  #     # Conditional execution with lambda
  #     process InternationalTask, unless: -> { context.order.domestic? }
  #
  #     # Conditional execution with method
  #     process DebugTask, if: :debug_mode?
  #
  #     private
  #
  #     def debug_mode?
  #       Rails.env.development?
  #     end
  #   end
  #
  # @example Custom halt behavior
  #   class StrictBatch < CMDx::Batch
  #     # Class-level halt configuration
  #     task_settings!(batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])
  #
  #     process CriticalTask
  #     process AnotherCriticalTask
  #   end
  #
  # @example Group-level halt behavior
  #   class FlexibleBatch < CMDx::Batch
  #     # Critical tasks - halt on any failure
  #     process CoreTask1, CoreTask2, batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
  #
  #     # Optional tasks - continue even if they fail
  #     process OptionalTask1, OptionalTask2, batch_halt: []
  #
  #     # Notification tasks - halt only on failures, allow skips
  #     process NotifyTask1, NotifyTask2  # Uses default halt behavior
  #   end
  #
  # @example Complex workflow
  #   class EcommerceCheckoutBatch < CMDx::Batch
  #     # Pre-processing
  #     process ValidateCartTask
  #     process CalculateShippingTask
  #
  #     # Payment processing (critical)
  #     process AuthorizePaymentTask, CapturePaymentTask,
  #       batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
  #
  #     # Fulfillment (conditional)
  #     process CreateShipmentTask, unless: :digital_only?
  #     process SendDigitalDeliveryTask, if: :has_digital_items?
  #
  #     # Post-processing notifications
  #     process SendConfirmationEmailTask
  #     process SendConfirmationSmsTask, if: proc { context.user.sms_enabled? }
  #
  #     private
  #
  #     def digital_only?
  #       context.order.items.all?(&:digital?)
  #     end
  #
  #     def has_digital_items?
  #       context.order.items.any?(&:digital?)
  #     end
  #   end
  #
  # @example Batch execution and result handling
  #   # Execute batch
  #   result = ProcessOrderBatch.call(order: order, user: current_user)
  #
  #   # Check results
  #   if result.success?
  #     redirect_to success_path
  #   elsif result.failed?
  #     # Handle failure - context contains data from all executed tasks
  #     flash[:error] = "Order processing failed: #{result.context.error_message}"
  #     redirect_to cart_path
  #   end
  #
  # @example Nested batches
  #   class MasterBatch < CMDx::Batch
  #     process PreProcessingBatch
  #     process CoreProcessingBatch
  #     process PostProcessingBatch
  #   end
  #
  # @see Task Base class providing hooks, parameters, and result tracking
  # @see Context Shared data object passed between tasks
  # @see Result Task execution results and status tracking
  # @since 0.6.0
  class Batch < Task

    ##
    # Represents a logical group of tasks with shared execution options.
    # Groups allow organizing related tasks and applying common configuration
    # such as conditional execution and halt behavior.
    #
    # @!attribute [r] tasks
    #   @return [Array<Class>] array of task classes to execute
    # @!attribute [r] options
    #   @return [Hash] execution options including conditions and halt behavior
    #
    # @example Group creation
    #   group = CMDx::Batch::Group.new(
    #     [TaskA, TaskB, TaskC],
    #     { if: proc { condition }, batch_halt: ["failed"] }
    #   )
    Group = Struct.new(:tasks, :options)

    class << self

      ##
      # Returns the collection of task groups defined for this batch.
      # Groups are created through `process` declarations and store
      # both the tasks to execute and their execution options.
      #
      # @return [Array<Group>] array of task groups in declaration order
      #
      # @example Accessing batch groups
      #   class MyBatch < CMDx::Batch
      #     process TaskA, TaskB
      #     process TaskC, if: proc { condition }
      #   end
      #
      #   MyBatch.batch_groups.size  #=> 2
      #   MyBatch.batch_groups.first.tasks  #=> [TaskA, TaskB]
      #   MyBatch.batch_groups.last.options  #=> { if: proc { condition } }
      #
      # @example Inspecting group configuration
      #   batch_class.batch_groups.each_with_index do |group, index|
      #     puts "Group #{index}: #{group.tasks.map(&:name).join(', ')}"
      #     puts "Options: #{group.options}" if group.options.any?
      #   end
      def batch_groups
        @batch_groups ||= []
      end

      ##
      # Declares tasks to be executed as part of this batch.
      # Tasks are organized into groups with shared execution options.
      # Multiple calls to `process` create separate groups that can have
      # different conditional logic and halt behavior.
      #
      # ## Supported Options
      #
      # - **`:if`** - Callable that must return truthy for group to execute
      # - **`:unless`** - Callable that must return falsy for group to execute
      # - **`:batch_halt`** - Array of result statuses that stop execution
      #
      # ## Conditional Callables
      #
      # Conditions can be:
      # - **Proc/Lambda**: Executed in batch instance context
      # - **Symbol**: Method name called on batch instance
      # - **String**: Method name called on batch instance
      #
      # @param tasks [Array<Class>] task classes that inherit from Task or Batch
      # @param options [Hash] execution options for this group
      #
      # @option options [Proc, Symbol, String] :if condition that must be truthy
      # @option options [Proc, Symbol, String] :unless condition that must be falsy
      # @option options [Array<Symbol>] :batch_halt result statuses that halt execution
      #
      # @raise [TypeError] if any task doesn't inherit from Task
      #
      # @example Basic task declaration
      #   class SimpleBatch < CMDx::Batch
      #     process TaskA
      #     process TaskB, TaskC
      #   end
      #
      # @example Conditional execution
      #   class ConditionalBatch < CMDx::Batch
      #     process AlwaysTask
      #
      #     # Proc condition
      #     process PremiumTask, if: proc { context.user.premium? }
      #
      #     # Lambda condition
      #     process InternationalTask, unless: -> { context.domestic_only? }
      #
      #     # Method condition
      #     process DebugTask, if: :debug_enabled?
      #
      #     private
      #
      #     def debug_enabled?
      #       Rails.env.development?
      #     end
      #   end
      #
      # @example Custom halt behavior
      #   class HaltBehaviorBatch < CMDx::Batch
      #     # Critical tasks - halt on any non-success
      #     process CriticalTaskA, CriticalTaskB,
      #       batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
      #
      #     # Optional tasks - never halt
      #     process OptionalTaskA, OptionalTaskB, batch_halt: []
      #
      #     # Default behavior tasks
      #     process NormalTaskA, NormalTaskB  # Halts on FAILED only
      #   end
      #
      # @example Complex conditions
      #   class ComplexBatch < CMDx::Batch
      #     process BaseTask
      #
      #     # Multiple conditions can be combined in proc
      #     process ConditionalTask, if: proc {
      #       context.user.active? &&
      #       context.feature_enabled?(:new_feature) &&
      #       Time.current.hour.between?(9, 17)
      #     }
      #
      #     # Conditional with custom halt behavior
      #     process RiskyTask,
      #       unless: :safe_mode?,
      #       batch_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
      #   end
      #
      # @example Nested batch processing
      #   class MasterBatch < CMDx::Batch
      #     process PreProcessingBatch
      #     process CoreBatch, if: proc { context.pre_processing_successful? }
      #     process PostProcessingBatch, unless: proc { context.skip_post_processing? }
      #   end
      def process(*tasks, **options)
        batch_groups << Group.new(
          tasks.flatten.map do |task|
            next task if task <= Task

            raise TypeError, "must be a Task or Batch"
          end,
          options
        )
      end

    end

    ##
    # Executes all defined task groups in sequential order.
    # This method is automatically defined and should not be overridden.
    # The execution flow handles conditional evaluation, task execution,
    # and halt behavior according to the batch configuration.
    #
    # ## Execution Algorithm
    #
    # 1. **Group Iteration**: Process each group in declaration order
    # 2. **Condition Evaluation**: Check `:if`/`:unless` conditions
    # 3. **Task Execution**: Run each task in the group sequentially
    # 4. **Result Evaluation**: Check task result against halt conditions
    # 5. **Halt Decision**: Stop execution or continue to next task
    # 6. **Context Propagation**: Pass updated context through pipeline
    #
    # ## Context Behavior
    #
    # The context object is shared across all tasks in the batch:
    # - Tasks can read data added by previous tasks
    # - Tasks can modify context for subsequent tasks
    # - Context persists throughout the entire batch execution
    # - Final context is available in the batch result
    #
    # ## Error Handling
    #
    # Batch execution follows the same error handling as individual tasks:
    # - Exceptions become failed results
    # - Faults are propagated through the result chain
    # - Halt behavior determines whether execution continues
    #
    # @return [Result] batch execution result with aggregated context
    #
    # @example Basic execution flow
    #   # Given this batch:
    #   class ProcessOrderBatch < CMDx::Batch
    #     process ValidateOrderTask      # Sets context.validation_result
    #     process CalculateTaxTask       # Uses context.order, sets context.tax_amount
    #     process ChargePaymentTask      # Uses context.tax_amount, sets context.payment_id
    #     process FulfillOrderTask       # Uses context.payment_id, sets context.tracking_number
    #   end
    #
    #   # Execution creates a pipeline:
    #   result = ProcessOrderBatch.call(order: order)
    #   result.context.validation_result  # From ValidateOrderTask
    #   result.context.tax_amount        # From CalculateTaxTask
    #   result.context.payment_id        # From ChargePaymentTask
    #   result.context.tracking_number   # From FulfillOrderTask
    #
    # @example Conditional execution
    #   # Given this batch:
    #   class ConditionalBatch < CMDx::Batch
    #     process TaskA                           # Always runs
    #     process TaskB, if: proc { context.run_b? }      # Conditional
    #     process TaskC, unless: proc { context.skip_c? } # Conditional
    #   end
    #
    #   # Execution evaluates conditions:
    #   # 1. TaskA runs (always)
    #   # 2. TaskB runs only if context.run_b? is truthy
    #   # 3. TaskC runs only if context.skip_c? is falsy
    #
    # @example Halt behavior
    #   # Given this batch with custom halt:
    #   class HaltBatch < CMDx::Batch
    #     process TaskA                    # Default halt (FAILED)
    #     process TaskB, TaskC, batch_halt: []  # Never halt
    #     process TaskD                    # Default halt (FAILED)
    #   end
    #
    #   # If TaskB fails:
    #   # - TaskB execution completes with failed status
    #   # - TaskC still executes (batch_halt: [] means no halt)
    #   # - TaskD still executes
    #   # - Batch continues to completion
    #
    #   # If TaskA fails:
    #   # - TaskA execution completes with failed status
    #   # - Batch halts (default behavior)
    #   # - TaskB, TaskC, TaskD never execute
    #   # - Batch result shows failed status
    #
    # @note Do not override this method. Batch execution logic is automatically
    #   provided and handles all the complexity of group processing, conditional
    #   evaluation, and halt behavior.
    #
    # @see Task#call Base task execution method
    # @see Context Shared data object
    # @see Result Task execution results
    def call
      self.class.batch_groups.each do |group|
        next unless __cmdx_eval(group.options)

        batch_halt = group.options[:batch_halt] || task_setting(:batch_halt)

        group.tasks.each do |task|
          task_result = task.call(context)
          next unless Array(batch_halt).include?(task_result.status)

          throw!(task_result)
        end
      end
    end

  end
end

# frozen_string_literal: true

module CMDx
  ##
  # Orchestrates sequential execution of multiple tasks in a linear pipeline.
  # Workflow provides a declarative DSL for composing complex business workflows
  # from individual task components, with support for conditional execution,
  # context passing, and configurable halt behavior.
  #
  # Workflows inherit from Task, gaining all task capabilities including callbacks,
  # parameter validation, result tracking, and configuration. The key difference
  # is that workflows coordinate other tasks rather than implementing business logic directly.
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
  # By default, workflows halt on `FAILED` status but continue on `SKIPPED`.
  # This reflects the philosophy that skipped tasks are bypass mechanisms,
  # not execution blockers. Halt behavior can be customized at class or group level.
  #
  # @example Basic workflow definition
  #   class ProcessOrderWorkflow < CMDx::Workflow
  #     process ValidateOrderTask
  #     process CalculateTaxTask
  #     process ChargePaymentTask
  #     process FulfillOrderTask
  #   end
  #
  # @example Multiple task declarations
  #   class NotificationWorkflow < CMDx::Workflow
  #     # Single task
  #     process PrepareNotificationTask
  #
  #     # Multiple tasks in one declaration
  #     process SendEmailTask, SendSmsTask, SendPushTask
  #   end
  #
  # @example Conditional execution
  #   class ConditionalWorkflow < CMDx::Workflow
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
  #   class StrictWorkflow < CMDx::Workflow
  #     # Class-level halt configuration
  #     task_settings!(workflow_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED])
  #
  #     process CriticalTask
  #     process AnotherCriticalTask
  #   end
  #
  # @example Group-level halt behavior
  #   class FlexibleWorkflow < CMDx::Workflow
  #     # Critical tasks - halt on any failure
  #     process CoreTask1, CoreTask2, workflow_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
  #
  #     # Optional tasks - continue even if they fail
  #     process OptionalTask1, OptionalTask2, workflow_halt: []
  #
  #     # Notification tasks - halt only on failures, allow skips
  #     process NotifyTask1, NotifyTask2  # Uses default halt behavior
  #   end
  #
  # @example Complex workflow
  #   class EcommerceCheckoutWorkflow < CMDx::Workflow
  #     # Pre-processing
  #     process ValidateCartTask
  #     process CalculateShippingTask
  #
  #     # Payment processing (critical)
  #     process AuthorizePaymentTask, CapturePaymentTask,
  #       workflow_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
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
  # @example Workflow execution and result handling
  #   # Execute workflow
  #   result = ProcessOrderWorkflow.call(order: order, user: current_user)
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
  # @example Nested workflows
  #   class MasterWorkflow < CMDx::Workflow
  #     process PreProcessingWorkflow
  #     process CoreProcessingWorkflow
  #     process PostProcessingWorkflow
  #   end
  #
  # @see Task Base class providing callbacks, parameters, and result tracking
  # @see Context Shared data object passed between tasks
  # @see Result Task execution results and status tracking
  # @since 1.0.0
  class Workflow < Task

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
    #   group = CMDx::Workflow::Group.new(
    #     [TaskA, TaskB, TaskC],
    #     { if: proc { condition }, workflow_halt: ["failed"] }
    #   )
    Group = Struct.new(:tasks, :options)

    class << self

      ##
      # Returns the collection of task groups defined for this workflow.
      # Groups are created through `process` declarations and store
      # both the tasks to execute and their execution options.
      #
      # @return [Array<Group>] array of task groups in declaration order
      #
      # @example Accessing workflow groups
      #   class MyWorkflow < CMDx::Workflow
      #     process TaskA, TaskB
      #     process TaskC, if: proc { condition }
      #   end
      #
      #   MyWorkflow.workflow_groups.size  #=> 2
      #   MyWorkflow.workflow_groups.first.tasks  #=> [TaskA, TaskB]
      #   MyWorkflow.workflow_groups.last.options  #=> { if: proc { condition } }
      #
      # @example Inspecting group configuration
      #   workflow_class.workflow_groups.each_with_index do |group, index|
      #     puts "Group #{index}: #{group.tasks.map(&:name).join(', ')}"
      #     puts "Options: #{group.options}" if group.options.any?
      #   end
      def workflow_groups
        @workflow_groups ||= []
      end

      ##
      # Declares tasks to be executed as part of this workflow.
      # Tasks are organized into groups with shared execution options.
      # Multiple calls to `process` create separate groups that can have
      # different conditional logic and halt behavior.
      #
      # ## Supported Options
      #
      # - **`:if`** - Callable that must return truthy for group to execute
      # - **`:unless`** - Callable that must return falsy for group to execute
      # - **`:workflow_halt`** - Array of result statuses that stop execution
      #
      # ## Conditional Callables
      #
      # Conditions can be:
      # - **Proc/Lambda**: Executed in workflow instance context
      # - **Symbol**: Method name called on workflow instance
      # - **String**: Method name called on workflow instance
      #
      # @param tasks [Array<Class>] task classes that inherit from Task or Workflow
      # @param options [Hash] execution options for this group
      #
      # @option options [Proc, Symbol, String] :if condition that must be truthy
      # @option options [Proc, Symbol, String] :unless condition that must be falsy
      # @option options [Array<Symbol>] :workflow_halt result statuses that halt execution
      #
      # @raise [TypeError] if any task doesn't inherit from Task
      #
      # @example Basic task declaration
      #   class SimpleWorkflow < CMDx::Workflow
      #     process TaskA
      #     process TaskB, TaskC
      #   end
      #
      # @example Conditional execution
      #   class ConditionalWorkflow < CMDx::Workflow
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
      #   class HaltBehaviorWorkflow < CMDx::Workflow
      #     # Critical tasks - halt on any non-success
      #     process CriticalTaskA, CriticalTaskB,
      #       workflow_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
      #
      #     # Optional tasks - never halt
      #     process OptionalTaskA, OptionalTaskB, workflow_halt: []
      #
      #     # Default behavior tasks
      #     process NormalTaskA, NormalTaskB  # Halts on FAILED only
      #   end
      #
      # @example Complex conditions
      #   class ComplexWorkflow < CMDx::Workflow
      #     process BaseTask
      #
      #     # Multiple conditions can be combined in proc
      #     process ConditionalTask, if: proc {
      #       context.user.active? &&
      #       context.feature_enabled?(:new_feature) &&
      #       Time.now.hour.between?(9, 17)
      #     }
      #
      #     # Conditional with custom halt behavior
      #     process RiskyTask,
      #       unless: :safe_mode?,
      #       workflow_halt: [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
      #   end
      #
      # @example Nested workflow processing
      #   class MasterWorkflow < CMDx::Workflow
      #     process PreProcessingWorkflow
      #     process CoreWorkflow, if: proc { context.pre_processing_successful? }
      #     process PostProcessingWorkflow, unless: proc { context.skip_post_processing? }
      #   end
      def process(*tasks, **options)
        workflow_groups << Group.new(
          tasks.flatten.map do |task|
            next task if task <= Task

            raise TypeError, "must be a Task or Workflow"
          end,
          options
        )
      end

    end

    ##
    # Executes all defined task groups in sequential order.
    # This method is automatically defined and should not be overridden.
    # The execution flow handles conditional evaluation, task execution,
    # and halt behavior according to the workflow configuration.
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
    # The context object is shared across all tasks in the workflow:
    # - Tasks can read data added by previous tasks
    # - Tasks can modify context for subsequent tasks
    # - Context persists throughout the entire workflow execution
    # - Final context is available in the workflow result
    #
    # ## Error Handling
    #
    # Workflow execution follows the same error handling as individual tasks:
    # - Exceptions become failed results
    # - Faults are propagated through the result chain
    # - Halt behavior determines whether execution continues
    #
    # @return [Result] workflow execution result with aggregated context
    #
    # @example Basic execution flow
    #   # Given this workflow:
    #   class ProcessOrderWorkflow < CMDx::Workflow
    #     process ValidateOrderTask      # Sets context.validation_result
    #     process CalculateTaxTask       # Uses context.order, sets context.tax_amount
    #     process ChargePaymentTask      # Uses context.tax_amount, sets context.payment_id
    #     process FulfillOrderTask       # Uses context.payment_id, sets context.tracking_number
    #   end
    #
    #   # Execution creates a pipeline:
    #   result = ProcessOrderWorkflow.call(order: order)
    #   result.context.validation_result  # From ValidateOrderTask
    #   result.context.tax_amount        # From CalculateTaxTask
    #   result.context.payment_id        # From ChargePaymentTask
    #   result.context.tracking_number   # From FulfillOrderTask
    #
    # @example Conditional execution
    #   # Given this workflow:
    #   class ConditionalWorkflow < CMDx::Workflow
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
    #   # Given this workflow with custom halt:
    #   class HaltWorkflow < CMDx::Workflow
    #     process TaskA                    # Default halt (FAILED)
    #     process TaskB, TaskC, workflow_halt: []  # Never halt
    #     process TaskD                    # Default halt (FAILED)
    #   end
    #
    #   # If TaskB fails:
    #   # - TaskB execution completes with failed status
    #   # - TaskC still executes (workflow_halt: [] means no halt)
    #   # - TaskD still executes
    #   # - Workflow continues to completion
    #
    #   # If TaskA fails:
    #   # - TaskA execution completes with failed status
    #   # - Workflow halts (default behavior)
    #   # - TaskB, TaskC, TaskD never execute
    #   # - Workflow result shows failed status
    #
    # @note Do not override this method. Workflow execution logic is automatically
    #   provided and handles all the complexity of group processing, conditional
    #   evaluation, and halt behavior.
    #
    # @see Task#call Base task execution method
    # @see Context Shared data object
    # @see Result Task execution results
    def call
      self.class.workflow_groups.each do |group|
        next unless cmdx_eval(group.options)

        workflow_halt = group.options[:workflow_halt] || task_setting(:workflow_halt)

        group.tasks.each do |task|
          task_result = task.call(context)
          next unless Array(workflow_halt).include?(task_result.status)

          throw!(task_result)
        end
      end
    end

  end
end

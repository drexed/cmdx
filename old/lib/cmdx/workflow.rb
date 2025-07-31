# frozen_string_literal: true

module CMDx
  # Sequential task execution orchestration system for CMDx framework.
  #
  # Workflow provides declarative composition of multiple tasks into linear pipelines
  # with conditional execution, context propagation, and configurable halt behavior.
  # Workflows inherit from Task, gaining all task capabilities including callbacks,
  # parameter validation, result tracking, and configuration while coordinating
  # other tasks rather than implementing business logic directly.
  class Workflow < Task

    # Data structure containing a group of tasks and their execution options.
    #
    # @!attribute [r] tasks
    #   @return [Array<Class>] array of Task or Workflow classes to execute
    # @!attribute [r] options
    #   @return [Hash] execution options including conditional and halt configuration
    Group = Struct.new(:tasks, :options)

    class << self

      # Returns the array of workflow groups defined for this workflow class.
      #
      # Each group contains tasks and their execution options. Groups are processed
      # sequentially during workflow execution, with each group's tasks executing
      # in order unless halted by a result status.
      #
      # @return [Array<Group>] array of workflow groups containing tasks and options
      #
      # @example Access workflow groups
      #   class MyWorkflow < CMDx::Workflow
      #     process TaskA, TaskB
      #     process TaskC, if: :condition_met?
      #   end
      #
      #   MyWorkflow.workflow_groups.size #=> 2
      #   MyWorkflow.workflow_groups.first.tasks #=> [TaskA, TaskB]
      def workflow_groups
        @workflow_groups ||= []
      end

      # Declares a group of tasks to execute sequentially with optional conditions.
      #
      # Tasks are executed in the order specified, with shared context propagated
      # between executions. Groups support conditional execution and configurable
      # halt behavior to control workflow flow based on task results.
      #
      # @param tasks [Array<Class>] Task or Workflow classes to execute in sequence
      # @param options [Hash] execution configuration options
      #
      # @option options [Proc, Symbol, String] :if condition that must be truthy for group execution
      # @option options [Proc, Symbol, String] :unless condition that must be falsy for group execution
      # @option options [String, Array<String>] :workflow_halt result statuses that halt workflow execution
      #
      # @return [void]
      #
      # @raise [TypeError] when tasks contain objects that are not Task or Workflow classes
      #
      # @example Declare sequential tasks
      #   class UserRegistrationWorkflow < CMDx::Workflow
      #     process CreateUserTask, SendWelcomeEmailTask
      #   end
      #
      # @example Declare conditional task group
      #   class OrderProcessingWorkflow < CMDx::Workflow
      #     process ValidateOrderTask
      #     process ChargePaymentTask, if: ->(workflow) { workflow.context.payment_required? }
      #     process ShipOrderTask, unless: :digital_product?
      #     process NotifyAdminTask, if: proc { context.admin.active? }
      #   end
      #
      # @example Configure halt behavior per group
      #   class DataProcessingWorkflow < CMDx::Workflow
      #     process LoadDataTask, ValidateDataTask, workflow_halt: %w[failed skipped]
      #     process OptionalCleanupTask, workflow_halt: []
      #   end
      def process(*tasks, **options)
        workflow_groups << Group.new(
          tasks.flatten.map do |task|
            next task if task.is_a?(Class) && (task <= Task)

            raise TypeError, "must be a Task or Workflow"
          end,
          options
        )
      end

    end

    # Each group is evaluated for conditional execution, and if the group should
    # execute, all tasks in the group are called in sequence. If any task returns
    # a status that matches the workflow halt criteria, execution is halted and
    # the result is thrown.
    #
    # @return [void]
    #
    # @raise [Fault] if a task fails and its status matches the workflow halt criteria
    #
    # @example Execute workflow
    #   workflow = MyWorkflow.new(user_id: 123)
    #   workflow.call
    def call
      self.class.workflow_groups.each do |group|
        next unless cmdx_eval(group.options)

        workflow_halt = Array(
          group.options[:workflow_halt] ||
          cmd_setting(:workflow_halt)
        ).map(&:to_s)

        group.tasks.each do |task|
          task_result = task.call(context)
          next unless workflow_halt.include?(task_result.status)

          throw!(task_result)
        end
      end
    end

  end
end

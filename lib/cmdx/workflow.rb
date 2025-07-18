# frozen_string_literal: true

module CMDx
  # Orchestrates sequential execution of multiple tasks and workflows with conditional logic and halt behavior.
  #
  # Workflow provides a powerful way to chain multiple tasks together with support for
  # conditional execution logic, customizable halt behavior, and automatic result tracking.
  # Tasks are organized into groups that can be conditionally executed based on runtime
  # conditions, and workflow execution can be halted based on individual task results.
  #
  # Workflows inherit all functionality from Task, including parameter validation,
  # middleware support, callback execution, and comprehensive result tracking. This
  # allows workflows to be used anywhere a task can be used, enabling composition
  # of complex business processes from simpler task components.
  class Workflow < Task

    # Container for holding a group of tasks and their execution options.
    #
    # Groups provide a way to organize related tasks with shared execution options
    # such as conditional logic and halt behavior. Each group contains an array of
    # tasks and a hash of execution options that control when and how the group executes.
    #
    # @!attribute [r] tasks
    #   @return [Array<Class>] array of task classes to execute in this group
    # @!attribute [r] options
    #   @return [Hash] execution options controlling group behavior
    Group = Struct.new(:tasks, :options)

    class << self

      # Returns the collection of workflow groups defined for this workflow.
      #
      # Groups are executed in the order they were defined using the {.process} method.
      # Each group contains tasks and execution options that control conditional
      # execution and halt behavior for that specific group.
      #
      # @return [Array<Group>] array of workflow groups to be executed in sequence
      #
      # @example Access workflow groups for inspection
      #   class UserRegistrationWorkflow < CMDx::Workflow
      #     process ValidateInputTask, CreateUserTask
      #     process SendWelcomeEmailTask, if: ->(workflow) { workflow.context.send_email? }
      #   end
      #
      #   UserRegistrationWorkflow.workflow_groups.size #=> 2
      #   UserRegistrationWorkflow.workflow_groups.first.tasks #=> [ValidateInputTask, CreateUserTask]
      def workflow_groups
        @workflow_groups ||= []
      end

      # Defines a group of tasks to be executed sequentially as part of this workflow.
      #
      # Tasks within a group are executed in the order specified, and all tasks in
      # a group share the same execution options. Groups themselves are executed
      # in the order they are defined using multiple {.process} calls.
      #
      # @param tasks [Array<Class>] task or workflow classes to include in this group
      # @param options [Hash] execution options for this group
      # @option options [Symbol, Array<Symbol>] :workflow_halt status values that will halt workflow execution when returned by any task in this group
      # @option options [Proc, Symbol] :if conditional that determines if this group should execute (proc receives workflow instance, symbol calls method on workflow)
      # @option options [Proc, Symbol] :unless conditional that determines if this group should be skipped (proc receives workflow instance, symbol calls method on workflow)
      #
      # @return [void]
      #
      # @raise [TypeError] if any task is not a Task or Workflow subclass
      #
      # @example Define a simple workflow group
      #   class OrderProcessingWorkflow < CMDx::Workflow
      #     process ValidateOrderTask, CalculateTotalsTask, ChargePaymentTask
      #   end
      #
      # @example Define multiple groups with different conditions
      #   class UserOnboardingWorkflow < CMDx::Workflow
      #     process CreateUserTask, ValidateUserTask, if: proc { context.validations_enabled? }
      #     process SendWelcomeEmailTask, if: ->(workflow) { workflow.context.notifications_enabled? }
      #     process NotifyAdminTask, unless: :test_environment?
      #   end
      #
      # @example Define workflow group with custom halt behavior
      #   class DataPipelineWorkflow < CMDx::Workflow
      #     process ExtractDataTask, TransformDataTask, workflow_halt: [:failed, :skipped]
      #     process LoadDataTask, PublishResultsTask, workflow_halt: :failed
      #   end
      #
      # @example Define workflow with nested workflows
      #   class ComplexProcessWorkflow < CMDx::Workflow
      #     process PreprocessingWorkflow, ValidationWorkflow
      #     process ProcessingWorkflow, if: ->(workflow) { workflow.context.validated? }
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

    # Executes all workflow groups in sequence with conditional logic and halt behavior.
    #
    # Each group is evaluated for conditional execution using :if and :unless options.
    # If a group should execute, all tasks in the group are called sequentially with
    # the workflow's context. If any task returns a status that matches the workflow
    # halt criteria, execution is immediately halted and the result is thrown as a fault.
    #
    # The workflow context is passed to each task, allowing tasks to share data and
    # build upon each other's results. Task execution follows the same patterns as
    # individual task execution, including middleware, callbacks, and error handling.
    #
    # @return [void]
    #
    # @raise [Fault] if a task fails and its status matches the workflow halt criteria
    #
    # @example Execute workflow
    #   workflow = UserRegistrationWorkflow.new(
    #     email: "user@example.com",
    #     send_notifications: true
    #   )
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

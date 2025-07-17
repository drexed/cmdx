# frozen_string_literal: true

module CMDx
  # Orchestrates sequential execution of multiple tasks and workflows.
  #
  # Workflow provides a way to chain multiple tasks together with conditional
  # execution logic and halt behavior. Tasks are organized into groups that can
  # be conditionally executed based on options, and execution can be halted
  # based on task results.
  class Workflow < Task

    # Container for holding a group of tasks and their execution options.
    #
    # @!attribute [r] tasks
    #   @return [Array<Task>] the tasks in this group
    # @!attribute [r] options
    #   @return [Hash] the execution options for this group
    Group = Struct.new(:tasks, :options)

    class << self

      # Returns the collection of workflow groups defined for this workflow.
      #
      # @return [Array<Group>] array of workflow groups to be executed
      #
      # @example Access workflow groups
      #   MyWorkflow.workflow_groups #=> [#<Group:...>, #<Group:...>]
      def workflow_groups
        @workflow_groups ||= []
      end

      # Defines a group of tasks to be executed as part of this workflow.
      #
      # @param tasks [Array<Task>] tasks to include in this workflow group
      # @param options [Hash] execution options for this group
      # @option options [Symbol, Array<Symbol>] :workflow_halt status values that will halt workflow execution
      # @option options [Proc] :if conditional proc that determines if this group should execute
      # @option options [Proc] :unless conditional proc that determines if this group should be skipped
      #
      # @return [void]
      #
      # @raise [TypeError] if any task is not a Task or Workflow subclass
      #
      # @example Define a simple workflow group
      #   MyWorkflow.process CreateUserTask, SendEmailTask
      #
      # @example Define a conditional workflow group
      #   MyWorkflow.process NotifyAdminTask, if: ->(workflow) { workflow.context.admin.active? }
      #
      # @example Define a workflow group with halt behavior
      #   MyWorkflow.process ValidateInputTask, ProcessDataTask, workflow_halt: :failed
      def process(*tasks, **options)
        workflow_groups << Group.new(
          tasks.flatten.map do |task|
            unless task.is_a?(Class) && (task <= Task)
              raise TypeError,
                    "must be a Task or Workflow"
            end

            task
          end,
          options
        )
      end

    end

    # Executes all workflow groups in sequence.
    #
    # Each group is evaluated for conditional execution, and if the group should
    # execute, all tasks in the group are called in sequence. If any task returns
    # a status that matches the workflow halt criteria, execution is halted and
    # the result is thrown.
    #
    # @return [void]
    #
    # @raise [Fault] if a task fails and its status matches the workflow halt criteria
    #
    # @example Execute workflow with halt on failure
    #   workflow = MyWorkflow.new(user_id: 123)
    #   workflow.call # Executes all groups until halt condition is met
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

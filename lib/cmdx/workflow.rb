# frozen_string_literal: true

module CMDx
  # Provides workflow execution capabilities by organizing tasks into execution groups.
  # Workflows allow you to define sequences of tasks that can be executed conditionally
  # with breakpoint handling and context management.
  module Workflow

    module ClassMethods

      # Prevents redefinition of the work method to maintain workflow integrity.
      #
      # @param method_name [Symbol] The name of the method being added
      #
      # @raise [RuntimeError] If attempting to redefine the work method
      #
      # @example
      #   class MyWorkflow
      #     include CMDx::Workflow
      #     # This would raise an error:
      #     # def work; end
      #   end
      def method_added(method_name)
        raise "cannot redefine #{name}##{method_name} method" if method_name == :work

        super
      end

      # Returns the collection of execution groups for this workflow.
      #
      # @return [Array<ExecutionGroup>] Array of execution groups
      #
      # @example
      #   class MyWorkflow
      #     include CMDx::Workflow
      #     task Task1
      #     task Task2
      #     puts pipeline.size # => 2
      #   end
      def pipeline
        @pipeline ||= []
      end

      # Adds multiple tasks to the workflow with optional configuration.
      #
      # @param tasks [Array<Class>] Array of task classes to add
      # @param options [Hash] Configuration options for the task execution
      # @option options [Hash] :breakpoints Breakpoints that trigger workflow interruption
      # @option options [Hash] :conditions Conditional logic for task execution
      #
      # @raise [TypeError] If any task is not a CMDx::Task subclass
      #
      # @example
      #   class MyWorkflow
      #     include CMDx::Workflow
      #     tasks ValidateTask, ProcessTask, NotifyTask, breakpoints: [:failure, :halt]
      #   end
      def tasks(*tasks, **options)
        pipeline << ExecutionGroup.new(
          tasks.map do |task|
            next task if task.is_a?(Class) && (task <= Task)

            raise TypeError, "must be a CMDx::Task"
          end,
          options
        )
      end
      alias task tasks

    end

    # Represents a group of tasks with shared execution options.
    # @attr tasks [Array<Class>] Array of task classes in this group
    # @attr options [Hash] Configuration options for the group
    ExecutionGroup = Struct.new(:tasks, :options)

    # Extends the including class with workflow capabilities.
    #
    # @param base [Class] The class including this module
    #
    # @example
    #   class MyWorkflow
    #     include CMDx::Workflow
    #     # Now has access to task, tasks, and work methods
    #   end
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Executes the workflow by processing all tasks in the pipeline.
    # This method delegates execution to the Pipeline class which handles
    # the processing of tasks with proper error handling and context management.
    #
    # @example
    #   class MyWorkflow
    #     include CMDx::Workflow
    #     task ValidateTask
    #     task ProcessTask
    #   end
    #
    #   workflow = MyWorkflow.new
    #   result = workflow.work
    def work
      Pipeline.execute(self)
    end

  end
end

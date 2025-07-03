# frozen_string_literal: true

module CMDx
  module Testing
    # Workflow builder utilities for creating test workflow classes
    #
    # This module provides convenient methods for creating CMDx::Workflow classes
    # for testing purposes. While tests can use manual `Class.new(CMDx::Workflow)`
    # patterns, these builders offer semantic shortcuts for common workflow scenarios
    # and improved semantic clarity.
    #
    # @note These builders are optional - tests can use direct `Class.new(CMDx::Workflow)`
    #   for maximum control and transparency, or these builders for convenience
    #   and improved test readability.
    #
    # @example Manual vs Builder Approach
    #   task1 = create_simple_task
    #   task2 = create_failing_task
    #   task3 = create_skipping_task
    #
    #   # Manual approach (explicit, full control)
    #   workflow_class = Class.new(CMDx::Workflow) do
    #     def self.name
    #       "OrderProcessingWorkflow"
    #     end
    #
    #     task_settings!(workflow_halt: [:failed], tags: [:orders])
    #     process task1
    #     process task2, task3
    #   end
    #
    #   # Builder approach (semantic, convenient)
    #   workflow_class = create_simple_workflow(
    #     tasks: [task1, task2, task3],
    #     name: "OrderProcessingWorkflow"
    #   )
    #
    # @example When to Use Manual vs Builder
    #   # Use manual approach when:
    #   # - You need complex workflow orchestration
    #   # - You have custom halt conditions or error handling
    #   # - You want maximum transparency in the test
    #   # - You need fine-grained control over task groupings
    #
    #   # Use builder approach when:
    #   # - Testing common workflow patterns (sequential, parallel, grouped)
    #   # - You want semantic clarity in test intent
    #   # - You need consistent workflow patterns across tests
    #   # - Testing straightforward task execution flows
    #
    # @since 1.0.0
    module WorkflowBuilders

      # @group Basic Workflow Creation

      # Creates a new workflow class with optional configuration
      #
      # This is the foundation method for creating CMDx workflow classes. It provides
      # a clean interface for creating workflow classes with optional naming and
      # custom behavior through block evaluation.
      #
      # @param name [String] name for the workflow class (defaults to "AnonymousWorkflow")
      # @param block [Proc] optional block to evaluate in workflow class context
      # @return [Class] new workflow class inheriting from CMDx::Workflow
      #
      # @example Basic workflow class creation
      #   workflow_class = create_workflow_class do
      #     process create_simple_task
      #     process create_failing_task, create_skipping_task
      #   end
      #
      # @example Named workflow class with settings
      #   workflow_class = create_workflow_class(name: "OrderProcessingWorkflow") do
      #     task_settings!(workflow_halt: [:failed], tags: [:orders])
      #     process create_simple_task(name: "ValidateOrder")
      #     process create_simple_task(name: "ProcessPayment")
      #   end
      #
      # @example Workflow class with complex configuration
      #   workflow_class = create_workflow_class(name: "DataPipelineWorkflow") do
      #     task_settings!(timeout: 300, retries: 2, tags: [:data, :pipeline])
      #
      #     # Sequential validation tasks
      #     process create_simple_task(name: "ValidateInput")
      #     process create_simple_task(name: "CheckPermissions")
      #
      #     # Parallel processing tasks
      #     process(
      #       create_simple_task(name: "ProcessData"),
      #       create_simple_task(name: "GenerateReport"),
      #       create_simple_task(name: "SendNotification")
      #     )
      #   end
      def create_workflow_class(name: "AnonymousWorkflow", &block)
        workflow_class = Class.new(CMDx::Workflow)
        workflow_class.define_singleton_method(:name) { name }
        workflow_class.class_eval(&block) if block_given?
        workflow_class
      end

      # Creates a simple sequential workflow from an array of tasks
      #
      # This is the most basic workflow type, processing tasks one after another
      # in the order specified. Each task runs individually in its own group,
      # ensuring sequential execution with proper dependency handling.
      #
      # @param tasks [Array<Class>] array of task classes to process sequentially
      # @param name [String] name for the workflow class (defaults to "SimpleWorkflow")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] workflow class that processes tasks sequentially
      #
      # @example Basic sequential workflow
      #   tasks = [
      #     create_simple_task(name: "Step1"),
      #     create_simple_task(name: "Step2"),
      #     create_simple_task(name: "Step3")
      #   ]
      #   workflow_class = create_simple_workflow(tasks: tasks)
      #   result = workflow_class.call
      #   expect(result).to be_success
      #
      # @example Named sequential workflow with configuration
      #   tasks = [
      #     create_simple_task(name: "LoadData"),
      #     create_simple_task(name: "ValidateData"),
      #     create_simple_task(name: "SaveData")
      #   ]
      #   workflow_class = create_simple_workflow(
      #     tasks: tasks,
      #     name: "DataProcessingWorkflow"
      #   ) do
      #     task_settings!(timeout: 60, tags: [:data_processing])
      #   end
      #
      # @example Testing sequential execution order
      #   execution_order = []
      #   tasks = [
      #     create_task_class(name: "First") { define_method(:call) { execution_order << :first } },
      #     create_task_class(name: "Second") { define_method(:call) { execution_order << :second } },
      #     create_task_class(name: "Third") { define_method(:call) { execution_order << :third } }
      #   ]
      #
      #   workflow_class = create_simple_workflow(tasks: tasks)
      #   workflow_class.call
      #   expect(execution_order).to eq([:first, :second, :third])
      def create_simple_workflow(tasks:, name: "SimpleWorkflow", &block)
        create_workflow_class(name: name) do
          Array(tasks).each { |task| process task }

          class_eval(&block) if block_given?
        end
      end

    end
  end
end

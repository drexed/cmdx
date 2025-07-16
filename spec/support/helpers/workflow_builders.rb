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
    #     cmd_settings!(workflow_halt: [:failed], tags: [:orders])
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
      #     cmd_settings!(workflow_halt: [:failed], tags: [:orders])
      #     process create_simple_task(name: "ValidateOrder")
      #     process create_simple_task(name: "ProcessPayment")
      #   end
      #
      # @example Workflow class with complex configuration
      #   workflow_class = create_workflow_class(name: "DataPipelineWorkflow") do
      #     cmd_settings!(timeout: 300, retries: 2, tags: [:data, :pipeline])
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
      def create_workflow_class(name: "AnonymousWorkflow", base: CMDx::Workflow, &block)
        workflow_class = Class.new(base)
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
      #     cmd_settings!(timeout: 60, tags: [:data_processing])
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
      def create_simple_workflow(tasks:, name: "SimpleWorkflow", base: CMDx::Workflow, &block)
        create_workflow_class(name:, base:) do
          Array(tasks).each { |task| process task }

          class_eval(&block) if block_given?
        end
      end

      # Creates a workflow that always succeeds with multiple successful tasks
      #
      # This workflow is designed for testing success scenarios and positive path
      # execution flows. It contains multiple successful tasks that will complete
      # without errors, making it ideal for testing workflow coordination,
      # context propagation, and success callbacks.
      #
      # @param name [String] name for the workflow class (defaults to "SuccessfulWorkflow")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] workflow class that will always succeed
      #
      # @example Basic successful workflow testing
      #   workflow_class = create_successful_workflow
      #   result = workflow_class.call
      #   expect(result).to be_success
      #   expect(result.status).to eq("success")
      #
      # @example Testing success callbacks and middleware
      #   callbacks_executed = []
      #   workflow_class = create_successful_workflow(name: "CallbackTestWorkflow") do
      #     on_success { |task| callbacks_executed << :success }
      #     on_executed { |task| callbacks_executed << :executed }
      #   end
      #
      #   result = workflow_class.call
      #   expect(callbacks_executed).to include(:success, :executed)
      #
      # @example Testing context propagation through successful tasks
      #   workflow_class = create_successful_workflow(name: "ContextWorkflow") do
      #     cmd_settings!(tags: [:success_testing])
      #   end
      #
      #   result = workflow_class.call(initial_data: "test")
      #   expect(result.context.initial_data).to eq("test")
      #   expect(result.context.executed).to be true
      def create_successful_workflow(name: "SuccessfulWorkflow", base: CMDx::Workflow, &block)
        create_workflow_class(name:, base:) do
          process create_successful_task
          process create_successful_task
          process create_successful_task

          class_eval(&block) if block_given?
        end
      end

      # Creates a workflow that includes skipped tasks for testing skip scenarios
      #
      # This workflow is designed for testing skip behavior and conditional execution
      # patterns. It contains a mix of successful and skipping tasks, making it ideal
      # for testing workflow halt behavior, skip callbacks, and conditional logic
      # when some tasks are intentionally bypassed.
      #
      # @param name [String] name for the workflow class (defaults to "SkippingWorkflow")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] workflow class that includes skipped tasks
      #
      # @example Basic skipping workflow testing
      #   workflow_class = create_skipping_workflow
      #   result = workflow_class.call
      #   expect(result).to be_success  # Workflow continues after skips by default
      #
      # @example Testing skip callbacks and handling
      #   skip_callbacks = []
      #   workflow_class = create_skipping_workflow(name: "SkipCallbackWorkflow") do
      #     on_skipped { |task| skip_callbacks << task.class.name }
      #   end
      #
      #   result = workflow_class.call
      #   expect(skip_callbacks).not_to be_empty
      #
      # @example Testing workflow halt on skip conditions
      #   workflow_class = create_skipping_workflow(name: "HaltOnSkipWorkflow") do
      #     cmd_settings!(workflow_halt: [:skipped])
      #   end
      #
      #   expect { workflow_class.call! }.to raise_error(CMDx::Fault)
      #
      # @example Testing mixed success and skip scenarios
      #   workflow_class = create_skipping_workflow(name: "MixedResultWorkflow")
      #   result = workflow_class.call(test_condition: true)
      #
      #   # Should complete successfully despite skipped tasks
      #   expect(result).to be_success
      #   expect(result.context.executed).to be true
      def create_skipping_workflow(name: "SkippingWorkflow", base: CMDx::Workflow, &block)
        create_workflow_class(name:, base:) do
          process create_successful_task
          process create_skipping_task
          process create_successful_task

          class_eval(&block) if block_given?
        end
      end

      # Creates a workflow that includes failing tasks for testing failure scenarios
      #
      # This workflow is designed for testing failure handling, error propagation,
      # and fault tolerance patterns. It contains a mix of successful and failing
      # tasks, making it ideal for testing workflow halt behavior, error callbacks,
      # and failure recovery mechanisms.
      #
      # @param name [String] name for the workflow class (defaults to "FailingWorkflow")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] workflow class that includes failing tasks
      #
      # @example Basic failing workflow testing
      #   workflow_class = create_failing_workflow
      #   result = workflow_class.call
      #   expect(result).to be_failed
      #
      # @example Testing failure callbacks and error handling
      #   error_callbacks = []
      #   workflow_class = create_failing_workflow(name: "ErrorHandlingWorkflow") do
      #     on_failed { |task| error_callbacks << task.result.metadata[:reason] }
      #   end
      #
      #   result = workflow_class.call
      #   expect(error_callbacks).not_to be_empty
      #
      # @example Testing workflow halt on failure (default behavior)
      #   workflow_class = create_failing_workflow(name: "HaltOnFailWorkflow")
      #
      #   expect { workflow_class.call! }.to raise_error(CMDx::Fault)
      #
      # @example Testing failure isolation and continuation
      #   workflow_class = create_failing_workflow(name: "ContinueOnFailWorkflow") do
      #     cmd_settings!(workflow_halt: [])  # Don't halt on any status
      #   end
      #
      #   result = workflow_class.call
      #   expect(result).to be_failed  # Overall workflow fails
      #   expect(result.context.executed).to be true  # But other tasks still ran
      #
      # @example Testing custom failure handling
      #   workflow_class = create_failing_workflow(name: "CustomFailureWorkflow") do
      #     cmd_settings!(workflow_halt: [:failed], tags: [:error_testing])
      #   end
      #
      #   result = workflow_class.call(error_context: "test")
      #   expect(result.context.error_context).to eq("test")
      def create_failing_workflow(name: "FailingWorkflow", base: CMDx::Workflow, &block)
        create_workflow_class(name:, base:) do
          process create_successful_task
          process create_failing_task
          process create_successful_task

          class_eval(&block) if block_given?
        end
      end

      # Creates a workflow that includes erroring tasks for testing exception scenarios
      #
      # This workflow is designed for testing exception handling, unexpected error
      # scenarios, and system fault tolerance. It contains a mix of successful and
      # erroring tasks, making it ideal for testing workflow exception propagation,
      # error callbacks, and system resilience under unexpected conditions.
      #
      # @param name [String] name for the workflow class (defaults to "ErroringWorkflow")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] workflow class that includes erroring tasks
      #
      # @example Basic erroring workflow testing
      #   workflow_class = create_erroring_workflow
      #   result = workflow_class.call
      #   expect(result).to be_failed  # Errors are converted to failures
      #
      # @example Testing exception handling and conversion
      #   workflow_class = create_erroring_workflow(name: "ExceptionWorkflow")
      #   result = workflow_class.call
      #
      #   expect(result).to be_failed
      #   expect(result.metadata[:original_exception]).to be_a(StandardError)
      #
      # @example Testing error callbacks and logging
      #   error_logs = []
      #   workflow_class = create_erroring_workflow(name: "ErrorLoggingWorkflow") do
      #     on_failed { |task| error_logs << task.result.metadata[:reason] }
      #   end
      #
      #   result = workflow_class.call
      #   expect(error_logs).not_to be_empty
      #   expect(error_logs.first).to include("StandardError")
      #
      # @example Testing system resilience with exceptions
      #   workflow_class = create_erroring_workflow(name: "ResilienceWorkflow") do
      #     cmd_settings!(workflow_halt: [], tags: [:resilience_testing])
      #   end
      #
      #   result = workflow_class.call(test_data: "resilience")
      #   expect(result).to be_failed  # Workflow fails due to error
      #   expect(result.context.test_data).to eq("resilience")  # Context preserved
      #
      # @example Testing error isolation and fault boundaries
      #   workflow_class = create_erroring_workflow(name: "FaultBoundaryWorkflow")
      #
      #   expect { workflow_class.call! }.to raise_error(CMDx::Fault)
      #
      # @note Erroring tasks throw StandardError exceptions which are caught by the
      #   CMDx system and converted to failed results. This allows testing of
      #   exception handling without breaking the workflow execution framework.
      def create_erroring_workflow(name: "ErroringWorkflow", base: CMDx::Workflow, &block)
        create_workflow_class(name:, base:) do
          process create_successful_task
          process create_erroring_task
          process create_successful_task

          class_eval(&block) if block_given?
        end
      end

    end
  end
end

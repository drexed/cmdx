# frozen_string_literal: true

require "securerandom"

module CMDx
  module Testing
    # Workflow testing helpers for mocking, stubbing, and creating test doubles
    #
    # This module provides comprehensive helper methods for testing CMDx workflows,
    # workflow groups, workflow results, and related components. It includes methods for
    # creating mock objects, stubbing workflow-specific behavior, and building test
    # scenarios for workflow workflows.
    #
    # @example Basic usage
    #   RSpec.describe MyWorkflow do
    #     it "processes successfully" do
    #       workflow = mock_workflow
    #       result = mock_workflow_success_result(workflow: workflow)
    #       expect(result).to be_success
    #     end
    #   end
    module WorkflowHelpers

      # @group Workflow Double Creation Methods

      # Creates a mock workflow double with realistic defaults
      #
      # This method creates a comprehensive workflow double that includes all the
      # standard workflow attributes and relationships. It's useful for testing
      # scenarios where you need a workflow object but don't want to create an
      # actual workflow class.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [String] :id workflow identifier
      # @option overrides [Class] :class workflow class double
      # @option overrides [Object] :chain associated chain
      # @option overrides [Object] :context workflow context
      # @option overrides [Object] :result workflow result
      # @option overrides [Array] :workflow_groups collection of workflow groups
      # @option overrides [Array] :tasks flattened tasks from all groups
      # @option overrides [Object] :errors workflow errors collection
      # @option overrides [Object] :cmd_middlewares middleware registry
      # @option overrides [Object] :cmd_callbacks callback registry
      # @option overrides [Array] :tags workflow tags
      #
      # @return [RSpec::Mocks::Double] configured workflow double
      #
      # @example Basic workflow mock
      #   workflow = mock_workflow
      #   expect(workflow.id).to match(/^test-workflow-/)
      #
      # @example Workflow mock with custom attributes
      #   workflow = mock_workflow(id: "custom-workflow", tags: [:processing, :orders])
      #   expect(workflow.tags).to eq([:processing, :orders])
      def mock_workflow(overrides = {})
        defaults = {
          id: "test-workflow-#{SecureRandom.hex(4)}",
          class: double("WorkflowClass", name: "TestWorkflow"),
          chain: mock_chain,
          context: mock_context,
          result: mock_result,
          workflow_groups: [],
          tasks: [],
          errors: double("Errors", empty?: true, full_messages: [], messages: {}),
          cmd_middlewares: double("MiddlewareRegistry"),
          cmd_callbacks: double("CallbackRegistry"),
          tags: []
        }

        double("Workflow", defaults.merge(overrides))
      end

      # Creates a mock workflow group double with realistic defaults
      #
      # This method creates a workflow group double that represents a collection
      # of tasks with associated execution options like conditional execution
      # and halt behavior.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [Array] :tasks collection of task classes
      # @option overrides [Hash] :options group execution options
      # @option overrides [Proc] :if conditional execution proc
      # @option overrides [Proc] :unless conditional execution proc
      # @option overrides [Array] :workflow_halt halt conditions
      # @option overrides [Array] :tags group tags
      #
      # @return [RSpec::Mocks::Double] configured workflow group double
      #
      # @example Basic workflow group mock
      #   group = mock_workflow_group
      #   expect(group.tasks).to eq([])
      #
      # @example Workflow group with tasks and options
      #   group = mock_workflow_group(
      #     tasks: [task_class],
      #     options: { workflow_halt: [:failed], if: proc { true } }
      #   )
      #   expect(group.options[:workflow_halt]).to eq([:failed])
      def mock_workflow_group(overrides = {})
        defaults = {
          tasks: [],
          options: {},
          to_a: [[], {}]
        }

        double("WorkflowGroup", defaults.merge(overrides))
      end

      # Creates a mock workflow chain double with realistic defaults
      #
      # This method creates a chain double specifically for workflow execution
      # that includes workflow-specific attributes and collection methods.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [String] :id chain identifier
      # @option overrides [Integer] :index current position
      # @option overrides [Array] :results collection of workflow results
      # @option overrides [Integer] :size chain size
      # @option overrides [Object] :first first result
      # @option overrides [Object] :last last result
      # @option overrides [String] :state chain state
      # @option overrides [String] :status overall status
      # @option overrides [String] :outcome final outcome
      # @option overrides [Integer] :runtime total execution time
      # @option overrides [Integer] :workflow_count number of workflows executed
      # @option overrides [Integer] :task_count total tasks executed
      #
      # @return [RSpec::Mocks::Double] configured workflow chain double
      #
      # @example Basic workflow chain mock
      #   chain = mock_workflow_chain
      #   expect(chain.status).to eq("success")
      #
      # @example Workflow chain with results
      #   chain = mock_workflow_chain(
      #     results: [result1, result2],
      #     workflow_count: 2,
      #     task_count: 5
      #   )
      #   expect(chain.workflow_count).to eq(2)
      def mock_workflow_chain(overrides = {})
        defaults = {
          id: "test-workflow-chain-#{SecureRandom.hex(4)}",
          index: 0,
          results: [],
          size: 0,
          first: nil,
          last: nil,
          state: "complete",
          status: "success",
          outcome: "success",
          runtime: 0,
          workflow_count: 0,
          task_count: 0
        }

        double("WorkflowChain", defaults.merge(overrides))
      end

      # Creates a flexible mock workflow context double
      #
      # This method creates a context double that accepts any method calls
      # and returns nil by default, while allowing specific attributes to
      # be configured with custom return values. It's enhanced for workflow
      # scenarios where context accumulates data across multiple tasks.
      #
      # @param attributes [Hash] specific attributes to configure
      # @return [RSpec::Mocks::Double] configured workflow context double
      #
      # @example Basic workflow context mock
      #   context = mock_workflow_context
      #   expect(context.any_attribute).to be_nil
      #
      # @example Workflow context with workflow data
      #   context = mock_workflow_context(
      #     user_data: { id: 123, email: "test@example.com" },
      #     processing_step: "validation",
      #     completed_tasks: ["validate", "transform"]
      #   )
      #   expect(context.processing_step).to eq("validation")
      def mock_workflow_context(attributes = {})
        context = double("WorkflowContext")

        # Allow any method to be called on context and return nil by default
        allow(context).to receive(:method_missing).and_return(nil)

        # Set specific attributes if provided
        attributes.each do |key, value|
          allow(context).to receive(key).and_return(value)
        end

        context
      end

      # @group Workflow Result Creation Methods

      # Creates a mock workflow result in successful state
      #
      # This is a convenience method for creating result doubles that represent
      # successful workflow execution with all appropriate attributes set.
      #
      # @param workflow [Object] workflow to associate with result (creates mock if nil)
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured success result double
      #
      # @example Basic workflow success result
      #   result = mock_workflow_success_result
      #   expect(result).to be_success
      #
      # @example Workflow success result with custom attributes
      #   result = mock_workflow_success_result(
      #     workflow: my_workflow,
      #     runtime: 250,
      #     tasks_completed: 5
      #   )
      #   expect(result.tasks_completed).to eq(5)
      def mock_workflow_success_result(workflow: nil, **attributes)
        result_attributes = {
          status: "success",
          state: "executed",
          outcome: "success",
          executed?: true,
          success?: true,
          failed?: false,
          skipped?: false,
          workflow_complete?: true
        }.merge(attributes)

        workflow ||= mock_workflow
        result_attributes[:task] = workflow
        mock_result(result_attributes)
      end

      # Creates a mock workflow result in failed state
      #
      # This is a convenience method for creating result doubles that represent
      # failed workflow execution with appropriate failure metadata.
      #
      # @param workflow [Object] workflow to associate with result (creates mock if nil)
      # @param reason [String] failure reason for metadata
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured failed result double
      #
      # @example Basic workflow failed result
      #   result = mock_workflow_failed_result
      #   expect(result).to be_failed
      #
      # @example Workflow failed result with custom reason
      #   result = mock_workflow_failed_result(
      #     reason: "Task validation failed",
      #     failed_task: "ProcessOrderTask",
      #     runtime: 100
      #   )
      #   expect(result.metadata[:failed_task]).to eq("ProcessOrderTask")
      def mock_workflow_failed_result(workflow: nil, reason: "Workflow execution failed", **attributes)
        result_attributes = {
          status: "failed",
          state: "executed",
          outcome: "failed",
          executed?: true,
          success?: false,
          failed?: true,
          skipped?: false,
          workflow_complete?: false,
          metadata: { reason: reason }
        }.merge(attributes)

        workflow ||= mock_workflow
        result_attributes[:task] = workflow
        mock_result(result_attributes)
      end

      # Creates a mock workflow result in skipped state
      #
      # This is a convenience method for creating result doubles that represent
      # skipped workflow execution with appropriate skip metadata.
      #
      # @param workflow [Object] workflow to associate with result (creates mock if nil)
      # @param reason [String] skip reason for metadata
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured skipped result double
      #
      # @example Basic workflow skipped result
      #   result = mock_workflow_skipped_result
      #   expect(result).to be_skipped
      #
      # @example Workflow skipped result with custom reason
      #   result = mock_workflow_skipped_result(
      #     reason: "Workflow conditions not met",
      #     skipped_at_task: "ConditionalTask"
      #   )
      #   expect(result.metadata[:skipped_at_task]).to eq("ConditionalTask")
      def mock_workflow_skipped_result(workflow: nil, reason: "Workflow execution skipped", **attributes)
        result_attributes = {
          status: "skipped",
          state: "executed",
          outcome: "skipped",
          executed?: true,
          success?: false,
          failed?: false,
          skipped?: true,
          workflow_complete?: false,
          metadata: { reason: reason }
        }.merge(attributes)

        workflow ||= mock_workflow
        result_attributes[:task] = workflow
        mock_result(result_attributes)
      end

      # @group Workflow Configuration Helpers

      # Stubs workflow configuration and settings
      #
      # This method stubs workflow-level configuration including halt behavior,
      # middleware, callbacks, and other workflow settings to control test execution.
      #
      # @param workflow_class [Class] workflow class to stub methods on
      # @param config [Hash] configuration options to stub
      # @option config [Array] :workflow_halt halt conditions
      # @option config [Array] :tags workflow tags
      # @option config [Hash] :task_settings task-level settings
      # @option config [Object] :cmd_middlewares middleware registry
      # @option config [Object] :cmd_callbacks callback registry
      # @return [void]
      #
      # @example Basic workflow configuration stubbing
      #   stub_workflow_configuration(MyWorkflow, workflow_halt: [:failed])
      #
      # @example Complex workflow configuration
      #   stub_workflow_configuration(
      #     MyWorkflow,
      #     workflow_halt: [:failed, :skipped],
      #     tags: [:processing, :orders],
      #     task_settings: { timeout: 30 }
      #   )
      def stub_workflow_configuration(workflow_class, config = {})
        # Stub workflow_halt configuration
        allow(workflow_class).to receive(:workflow_halt).and_return(config[:workflow_halt]) if config[:workflow_halt]

        # Stub tags
        allow(workflow_class).to receive(:tags).and_return(config[:tags]) if config[:tags]

        # Stub task_settings
        allow(workflow_class).to receive(:task_settings!).with(config[:task_settings]) if config[:task_settings]

        # Stub middleware and callback registries
        allow(workflow_class).to receive(:cmd_middlewares).and_return(config[:cmd_middlewares]) if config[:cmd_middlewares]

        return unless config[:cmd_callbacks]

        allow(workflow_class).to receive(:cmd_callbacks).and_return(config[:cmd_callbacks])
      end

      # Stubs workflow group execution behavior
      #
      # This method stubs workflow group processing to control which groups
      # execute and under what conditions, useful for testing conditional
      # workflow execution and halt behavior.
      #
      # @param workflow_instance [Object] workflow instance to stub methods on
      # @param groups [Array] collection of workflow groups to return
      # @param execution_results [Hash] results for specific groups
      # @return [void]
      #
      # @example Stub workflow group execution
      #   stub_workflow_groups(
      #     workflow_instance,
      #     groups: [group1, group2],
      #     execution_results: { group1 => success_result, group2 => failed_result }
      #   )
      def stub_workflow_groups(workflow_instance, groups: [], execution_results: {})
        allow(workflow_instance).to receive(:workflow_groups).and_return(groups)

        groups.each do |group|
          if execution_results[group]
            allow(workflow_instance).to receive(:execute_group).with(group).and_return(execution_results[group])
          else
            allow(workflow_instance).to receive(:execute_group).with(group)
          end
        end
      end

      # Stubs workflow conditional execution methods
      #
      # This method stubs conditional execution logic for workflow groups,
      # including if/unless conditions and halt behavior evaluation.
      #
      # @param workflow_instance [Object] workflow instance to stub methods on
      # @param conditions [Hash] condition results for groups
      # @option conditions [Boolean] :if_condition result of if condition
      # @option conditions [Boolean] :unless_condition result of unless condition
      # @option conditions [Boolean] :should_halt whether execution should halt
      # @return [void]
      #
      # @example Stub conditional execution
      #   stub_workflow_conditions(
      #     workflow_instance,
      #     conditions: {
      #       if_condition: true,
      #       unless_condition: false,
      #       should_halt: false
      #     }
      #   )
      def stub_workflow_conditions(workflow_instance, conditions: {})
        allow(workflow_instance).to receive(:evaluate_if_condition).and_return(conditions[:if_condition]) if conditions.key?(:if_condition)

        allow(workflow_instance).to receive(:evaluate_unless_condition).and_return(conditions[:unless_condition]) if conditions.key?(:unless_condition)

        return unless conditions.key?(:should_halt)

        allow(workflow_instance).to receive(:should_halt?).and_return(conditions[:should_halt])
      end

      # @group Workflow Workflow Helpers

      # Stubs workflow workflow execution for integration testing
      #
      # This method provides a high-level way to stub entire workflow workflow
      # execution, including task progression, context updates, and result
      # aggregation across multiple workflow steps.
      #
      # @param workflow_class [Class] workflow class to stub workflow for
      # @param workflow_steps [Array] sequence of execution steps
      # @param final_result [Object] final workflow execution result
      # @return [void]
      #
      # @example Stub workflow workflow
      #   stub_workflow_workflow(
      #     OrderProcessingWorkflow,
      #     workflow_steps: [
      #       { step: :validation, result: success_result },
      #       { step: :processing, result: success_result },
      #       { step: :completion, result: success_result }
      #     ],
      #     final_result: workflow_success_result
      #   )
      def stub_workflow_workflow(workflow_class, workflow_steps: [], final_result: nil)
        workflow_steps.each do |step|
          step_name = step[:step]
          step_result = step[:result]
          allow(workflow_class).to receive(:"execute_#{step_name}").and_return(step_result)
        end

        return unless final_result

        allow(workflow_class).to receive(:call).and_return(final_result)
      end

      # Stubs workflow task serialization for logging and debugging
      #
      # This method stubs task serialization methods specifically for workflow
      # contexts where task information needs to be serialized differently
      # than in standalone task execution.
      #
      # @param serialized_data [Hash] data to return from workflow task serialization
      # @return [void]
      #
      # @example Stub workflow task serialization
      #   stub_workflow_task_serialization({
      #     type: "Workflow",
      #     class: "OrderProcessingWorkflow",
      #     tasks_count: 4,
      #     groups_count: 2
      #   })
      def stub_workflow_task_serialization(serialized_data = {})
        default_data = {
          type: "Workflow",
          class: "TestWorkflow",
          tasks_count: 0,
          groups_count: 0
        }.merge(serialized_data)

        allow(CMDx::TaskSerializer).to receive(:call) do |task|
          if task.is_a?(CMDx::Workflow) || (task.respond_to?(:class) && task.class.name&.include?("Workflow"))
            default_data
          else
            # Let other serializations pass through
            CMDx::TaskSerializer.call(task)
          end
        end
      end

      # @group Workflow Integration Helpers

      # Creates a mock workflow execution chain for integration testing
      #
      # This method creates a complete workflow execution chain including
      # multiple workflow instances, their results, and the overall chain
      # progression for testing complex workflow workflows.
      #
      # @param workflows [Array] collection of workflow instances
      # @param chain_status [String] overall chain status
      # @param execution_order [Array] order of workflow execution
      # @return [RSpec::Mocks::Double] configured workflow execution chain
      #
      # @example Create workflow execution chain
      #   chain = mock_workflow_execution_chain(
      #     workflows: [workflow1, workflow2, workflow3],
      #     chain_status: "success",
      #     execution_order: [:preprocessing, :main_processing, :postprocessing]
      #   )
      #   expect(chain.status).to eq("success")
      def mock_workflow_execution_chain(workflows: [], chain_status: "success", execution_order: [])
        results = workflows.map.with_index do |workflow, index|
          step_name = execution_order[index] || :"step_#{index + 1}"
          mock_workflow_success_result(
            workflow: workflow,
            metadata: { step: step_name, position: index }
          )
        end

        mock_workflow_chain(
          results: results,
          size: workflows.size,
          status: chain_status,
          workflow_count: workflows.size,
          task_count: workflows.sum { |b| (b.respond_to?(:tasks) ? b.tasks.size : 0) }
        )
      end

      # Stubs workflow error handling and recovery mechanisms
      #
      # This method stubs error handling behavior for workflow execution,
      # including retry logic, fallback mechanisms, and error propagation
      # strategies specific to workflow workflows.
      #
      # @param workflow_instance [Object] workflow instance to stub error handling for
      # @param error_config [Hash] error handling configuration
      # @option error_config [Integer] :max_retries maximum retry attempts
      # @option error_config [Array] :retryable_errors types of errors to retry
      # @option error_config [Boolean] :use_fallback whether to use fallback logic
      # @option error_config [Object] :fallback_result result to return on fallback
      # @return [void]
      #
      # @example Stub workflow error handling
      #   stub_workflow_error_handling(
      #     workflow_instance,
      #     error_config: {
      #       max_retries: 3,
      #       retryable_errors: [StandardError, TimeoutError],
      #       use_fallback: true,
      #       fallback_result: fallback_success_result
      #     }
      #   )
      def stub_workflow_error_handling(workflow_instance, error_config: {})
        allow(workflow_instance).to receive(:max_retries).and_return(error_config[:max_retries]) if error_config[:max_retries]

        allow(workflow_instance).to receive(:retryable_errors).and_return(error_config[:retryable_errors]) if error_config[:retryable_errors]

        allow(workflow_instance).to receive(:use_fallback?).and_return(error_config[:use_fallback]) if error_config[:use_fallback]

        return unless error_config[:fallback_result]

        allow(workflow_instance).to receive(:execute_fallback).and_return(error_config[:fallback_result])
      end

    end
  end
end

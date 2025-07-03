# frozen_string_literal: true

require "securerandom"

module CMDx
  module Testing
    # Batch testing helpers for mocking, stubbing, and creating test doubles
    #
    # This module provides comprehensive helper methods for testing CMDx batches,
    # batch groups, batch results, and related components. It includes methods for
    # creating mock objects, stubbing batch-specific behavior, and building test
    # scenarios for batch workflows.
    #
    # @example Basic usage
    #   RSpec.describe MyBatch do
    #     it "processes successfully" do
    #       batch = mock_batch
    #       result = mock_batch_success_result(batch: batch)
    #       expect(result).to be_success
    #     end
    #   end
    module BatchHelpers

      # @group Batch Double Creation Methods

      # Creates a mock batch double with realistic defaults
      #
      # This method creates a comprehensive batch double that includes all the
      # standard batch attributes and relationships. It's useful for testing
      # scenarios where you need a batch object but don't want to create an
      # actual batch class.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [String] :id batch identifier
      # @option overrides [Class] :class batch class double
      # @option overrides [Object] :chain associated chain
      # @option overrides [Object] :context batch context
      # @option overrides [Object] :result batch result
      # @option overrides [Array] :batch_groups collection of batch groups
      # @option overrides [Array] :tasks flattened tasks from all groups
      # @option overrides [Object] :errors batch errors collection
      # @option overrides [Object] :cmd_middlewares middleware registry
      # @option overrides [Object] :cmd_callbacks callback registry
      # @option overrides [Array] :tags batch tags
      #
      # @return [RSpec::Mocks::Double] configured batch double
      #
      # @example Basic batch mock
      #   batch = mock_batch
      #   expect(batch.id).to match(/^test-batch-/)
      #
      # @example Batch mock with custom attributes
      #   batch = mock_batch(id: "custom-batch", tags: [:processing, :orders])
      #   expect(batch.tags).to eq([:processing, :orders])
      def mock_batch(overrides = {})
        defaults = {
          id: "test-batch-#{SecureRandom.hex(4)}",
          class: double("BatchClass", name: "TestBatch"),
          chain: mock_chain,
          context: mock_context,
          result: mock_result,
          batch_groups: [],
          tasks: [],
          errors: double("Errors", empty?: true, full_messages: [], messages: {}),
          cmd_middlewares: double("MiddlewareRegistry"),
          cmd_callbacks: double("CallbackRegistry"),
          tags: []
        }

        double("Batch", defaults.merge(overrides))
      end

      # Creates a mock batch group double with realistic defaults
      #
      # This method creates a batch group double that represents a collection
      # of tasks with associated execution options like conditional execution
      # and halt behavior.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [Array] :tasks collection of task classes
      # @option overrides [Hash] :options group execution options
      # @option overrides [Proc] :if conditional execution proc
      # @option overrides [Proc] :unless conditional execution proc
      # @option overrides [Array] :batch_halt halt conditions
      # @option overrides [Array] :tags group tags
      #
      # @return [RSpec::Mocks::Double] configured batch group double
      #
      # @example Basic batch group mock
      #   group = mock_batch_group
      #   expect(group.tasks).to eq([])
      #
      # @example Batch group with tasks and options
      #   group = mock_batch_group(
      #     tasks: [task_class],
      #     options: { batch_halt: [:failed], if: proc { true } }
      #   )
      #   expect(group.options[:batch_halt]).to eq([:failed])
      def mock_batch_group(overrides = {})
        defaults = {
          tasks: [],
          options: {},
          to_a: [[], {}]
        }

        double("BatchGroup", defaults.merge(overrides))
      end

      # Creates a mock batch chain double with realistic defaults
      #
      # This method creates a chain double specifically for batch execution
      # that includes batch-specific attributes and collection methods.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [String] :id chain identifier
      # @option overrides [Integer] :index current position
      # @option overrides [Array] :results collection of batch results
      # @option overrides [Integer] :size chain size
      # @option overrides [Object] :first first result
      # @option overrides [Object] :last last result
      # @option overrides [String] :state chain state
      # @option overrides [String] :status overall status
      # @option overrides [String] :outcome final outcome
      # @option overrides [Integer] :runtime total execution time
      # @option overrides [Integer] :batch_count number of batches executed
      # @option overrides [Integer] :task_count total tasks executed
      #
      # @return [RSpec::Mocks::Double] configured batch chain double
      #
      # @example Basic batch chain mock
      #   chain = mock_batch_chain
      #   expect(chain.status).to eq("success")
      #
      # @example Batch chain with results
      #   chain = mock_batch_chain(
      #     results: [result1, result2],
      #     batch_count: 2,
      #     task_count: 5
      #   )
      #   expect(chain.batch_count).to eq(2)
      def mock_batch_chain(overrides = {})
        defaults = {
          id: "test-batch-chain-#{SecureRandom.hex(4)}",
          index: 0,
          results: [],
          size: 0,
          first: nil,
          last: nil,
          state: "complete",
          status: "success",
          outcome: "success",
          runtime: 0,
          batch_count: 0,
          task_count: 0
        }

        double("BatchChain", defaults.merge(overrides))
      end

      # Creates a flexible mock batch context double
      #
      # This method creates a context double that accepts any method calls
      # and returns nil by default, while allowing specific attributes to
      # be configured with custom return values. It's enhanced for batch
      # scenarios where context accumulates data across multiple tasks.
      #
      # @param attributes [Hash] specific attributes to configure
      # @return [RSpec::Mocks::Double] configured batch context double
      #
      # @example Basic batch context mock
      #   context = mock_batch_context
      #   expect(context.any_attribute).to be_nil
      #
      # @example Batch context with workflow data
      #   context = mock_batch_context(
      #     user_data: { id: 123, email: "test@example.com" },
      #     processing_step: "validation",
      #     completed_tasks: ["validate", "transform"]
      #   )
      #   expect(context.processing_step).to eq("validation")
      def mock_batch_context(attributes = {})
        context = double("BatchContext")

        # Allow any method to be called on context and return nil by default
        allow(context).to receive(:method_missing).and_return(nil)

        # Set specific attributes if provided
        attributes.each do |key, value|
          allow(context).to receive(key).and_return(value)
        end

        context
      end

      # @group Batch Result Creation Methods

      # Creates a mock batch result in successful state
      #
      # This is a convenience method for creating result doubles that represent
      # successful batch execution with all appropriate attributes set.
      #
      # @param batch [Object] batch to associate with result (creates mock if nil)
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured success result double
      #
      # @example Basic batch success result
      #   result = mock_batch_success_result
      #   expect(result).to be_success
      #
      # @example Batch success result with custom attributes
      #   result = mock_batch_success_result(
      #     batch: my_batch,
      #     runtime: 250,
      #     tasks_completed: 5
      #   )
      #   expect(result.tasks_completed).to eq(5)
      def mock_batch_success_result(batch: nil, **attributes)
        result_attributes = {
          status: "success",
          state: "executed",
          outcome: "success",
          executed?: true,
          success?: true,
          failed?: false,
          skipped?: false,
          batch_complete?: true
        }.merge(attributes)

        batch ||= mock_batch
        result_attributes[:task] = batch
        mock_result(result_attributes)
      end

      # Creates a mock batch result in failed state
      #
      # This is a convenience method for creating result doubles that represent
      # failed batch execution with appropriate failure metadata.
      #
      # @param batch [Object] batch to associate with result (creates mock if nil)
      # @param reason [String] failure reason for metadata
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured failed result double
      #
      # @example Basic batch failed result
      #   result = mock_batch_failed_result
      #   expect(result).to be_failed
      #
      # @example Batch failed result with custom reason
      #   result = mock_batch_failed_result(
      #     reason: "Task validation failed",
      #     failed_task: "ProcessOrderTask",
      #     runtime: 100
      #   )
      #   expect(result.metadata[:failed_task]).to eq("ProcessOrderTask")
      def mock_batch_failed_result(batch: nil, reason: "Batch execution failed", **attributes)
        result_attributes = {
          status: "failed",
          state: "executed",
          outcome: "failed",
          executed?: true,
          success?: false,
          failed?: true,
          skipped?: false,
          batch_complete?: false,
          metadata: { reason: reason }
        }.merge(attributes)

        batch ||= mock_batch
        result_attributes[:task] = batch
        mock_result(result_attributes)
      end

      # Creates a mock batch result in skipped state
      #
      # This is a convenience method for creating result doubles that represent
      # skipped batch execution with appropriate skip metadata.
      #
      # @param batch [Object] batch to associate with result (creates mock if nil)
      # @param reason [String] skip reason for metadata
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured skipped result double
      #
      # @example Basic batch skipped result
      #   result = mock_batch_skipped_result
      #   expect(result).to be_skipped
      #
      # @example Batch skipped result with custom reason
      #   result = mock_batch_skipped_result(
      #     reason: "Batch conditions not met",
      #     skipped_at_task: "ConditionalTask"
      #   )
      #   expect(result.metadata[:skipped_at_task]).to eq("ConditionalTask")
      def mock_batch_skipped_result(batch: nil, reason: "Batch execution skipped", **attributes)
        result_attributes = {
          status: "skipped",
          state: "executed",
          outcome: "skipped",
          executed?: true,
          success?: false,
          failed?: false,
          skipped?: true,
          batch_complete?: false,
          metadata: { reason: reason }
        }.merge(attributes)

        batch ||= mock_batch
        result_attributes[:task] = batch
        mock_result(result_attributes)
      end

      # @group Batch Configuration Helpers

      # Stubs batch configuration and settings
      #
      # This method stubs batch-level configuration including halt behavior,
      # middleware, callbacks, and other batch settings to control test execution.
      #
      # @param batch_class [Class] batch class to stub methods on
      # @param config [Hash] configuration options to stub
      # @option config [Array] :batch_halt halt conditions
      # @option config [Array] :tags batch tags
      # @option config [Hash] :task_settings task-level settings
      # @option config [Object] :cmd_middlewares middleware registry
      # @option config [Object] :cmd_callbacks callback registry
      # @return [void]
      #
      # @example Basic batch configuration stubbing
      #   stub_batch_configuration(MyBatch, batch_halt: [:failed])
      #
      # @example Complex batch configuration
      #   stub_batch_configuration(
      #     MyBatch,
      #     batch_halt: [:failed, :skipped],
      #     tags: [:processing, :orders],
      #     task_settings: { timeout: 30 }
      #   )
      def stub_batch_configuration(batch_class, config = {})
        # Stub batch_halt configuration
        allow(batch_class).to receive(:batch_halt).and_return(config[:batch_halt]) if config[:batch_halt]

        # Stub tags
        allow(batch_class).to receive(:tags).and_return(config[:tags]) if config[:tags]

        # Stub task_settings
        allow(batch_class).to receive(:task_settings!).with(config[:task_settings]) if config[:task_settings]

        # Stub middleware and callback registries
        allow(batch_class).to receive(:cmd_middlewares).and_return(config[:cmd_middlewares]) if config[:cmd_middlewares]

        return unless config[:cmd_callbacks]

        allow(batch_class).to receive(:cmd_callbacks).and_return(config[:cmd_callbacks])
      end

      # Stubs batch group execution behavior
      #
      # This method stubs batch group processing to control which groups
      # execute and under what conditions, useful for testing conditional
      # batch execution and halt behavior.
      #
      # @param batch_instance [Object] batch instance to stub methods on
      # @param groups [Array] collection of batch groups to return
      # @param execution_results [Hash] results for specific groups
      # @return [void]
      #
      # @example Stub batch group execution
      #   stub_batch_groups(
      #     batch_instance,
      #     groups: [group1, group2],
      #     execution_results: { group1 => success_result, group2 => failed_result }
      #   )
      def stub_batch_groups(batch_instance, groups: [], execution_results: {})
        allow(batch_instance).to receive(:batch_groups).and_return(groups)

        groups.each do |group|
          if execution_results[group]
            allow(batch_instance).to receive(:execute_group).with(group).and_return(execution_results[group])
          else
            allow(batch_instance).to receive(:execute_group).with(group)
          end
        end
      end

      # Stubs batch conditional execution methods
      #
      # This method stubs conditional execution logic for batch groups,
      # including if/unless conditions and halt behavior evaluation.
      #
      # @param batch_instance [Object] batch instance to stub methods on
      # @param conditions [Hash] condition results for groups
      # @option conditions [Boolean] :if_condition result of if condition
      # @option conditions [Boolean] :unless_condition result of unless condition
      # @option conditions [Boolean] :should_halt whether execution should halt
      # @return [void]
      #
      # @example Stub conditional execution
      #   stub_batch_conditions(
      #     batch_instance,
      #     conditions: {
      #       if_condition: true,
      #       unless_condition: false,
      #       should_halt: false
      #     }
      #   )
      def stub_batch_conditions(batch_instance, conditions: {})
        allow(batch_instance).to receive(:evaluate_if_condition).and_return(conditions[:if_condition]) if conditions.key?(:if_condition)

        allow(batch_instance).to receive(:evaluate_unless_condition).and_return(conditions[:unless_condition]) if conditions.key?(:unless_condition)

        return unless conditions.key?(:should_halt)

        allow(batch_instance).to receive(:should_halt?).and_return(conditions[:should_halt])
      end

      # @group Batch Workflow Helpers

      # Stubs batch workflow execution for integration testing
      #
      # This method provides a high-level way to stub entire batch workflow
      # execution, including task progression, context updates, and result
      # aggregation across multiple batch steps.
      #
      # @param batch_class [Class] batch class to stub workflow for
      # @param workflow_steps [Array] sequence of execution steps
      # @param final_result [Object] final batch execution result
      # @return [void]
      #
      # @example Stub batch workflow
      #   stub_batch_workflow(
      #     OrderProcessingBatch,
      #     workflow_steps: [
      #       { step: :validation, result: success_result },
      #       { step: :processing, result: success_result },
      #       { step: :completion, result: success_result }
      #     ],
      #     final_result: batch_success_result
      #   )
      def stub_batch_workflow(batch_class, workflow_steps: [], final_result: nil)
        workflow_steps.each do |step|
          step_name = step[:step]
          step_result = step[:result]
          allow(batch_class).to receive(:"execute_#{step_name}").and_return(step_result)
        end

        return unless final_result

        allow(batch_class).to receive(:call).and_return(final_result)
      end

      # Stubs batch task serialization for logging and debugging
      #
      # This method stubs task serialization methods specifically for batch
      # contexts where task information needs to be serialized differently
      # than in standalone task execution.
      #
      # @param serialized_data [Hash] data to return from batch task serialization
      # @return [void]
      #
      # @example Stub batch task serialization
      #   stub_batch_task_serialization({
      #     type: "Batch",
      #     class: "OrderProcessingBatch",
      #     tasks_count: 4,
      #     groups_count: 2
      #   })
      def stub_batch_task_serialization(serialized_data = {})
        default_data = {
          type: "Batch",
          class: "TestBatch",
          tasks_count: 0,
          groups_count: 0
        }.merge(serialized_data)

        allow(CMDx::TaskSerializer).to receive(:call) do |task|
          if task.is_a?(CMDx::Batch) || (task.respond_to?(:class) && task.class.name&.include?("Batch"))
            default_data
          else
            # Let other serializations pass through
            CMDx::TaskSerializer.call(task)
          end
        end
      end

      # @group Batch Integration Helpers

      # Creates a mock batch execution chain for integration testing
      #
      # This method creates a complete batch execution chain including
      # multiple batch instances, their results, and the overall chain
      # progression for testing complex batch workflows.
      #
      # @param batches [Array] collection of batch instances
      # @param chain_status [String] overall chain status
      # @param execution_order [Array] order of batch execution
      # @return [RSpec::Mocks::Double] configured batch execution chain
      #
      # @example Create batch execution chain
      #   chain = mock_batch_execution_chain(
      #     batches: [batch1, batch2, batch3],
      #     chain_status: "success",
      #     execution_order: [:preprocessing, :main_processing, :postprocessing]
      #   )
      #   expect(chain.status).to eq("success")
      def mock_batch_execution_chain(batches: [], chain_status: "success", execution_order: [])
        results = batches.map.with_index do |batch, index|
          step_name = execution_order[index] || :"step_#{index + 1}"
          mock_batch_success_result(
            batch: batch,
            metadata: { step: step_name, position: index }
          )
        end

        mock_batch_chain(
          results: results,
          size: batches.size,
          status: chain_status,
          batch_count: batches.size,
          task_count: batches.sum { |b| (b.respond_to?(:tasks) ? b.tasks.size : 0) }
        )
      end

      # Stubs batch error handling and recovery mechanisms
      #
      # This method stubs error handling behavior for batch execution,
      # including retry logic, fallback mechanisms, and error propagation
      # strategies specific to batch workflows.
      #
      # @param batch_instance [Object] batch instance to stub error handling for
      # @param error_config [Hash] error handling configuration
      # @option error_config [Integer] :max_retries maximum retry attempts
      # @option error_config [Array] :retryable_errors types of errors to retry
      # @option error_config [Boolean] :use_fallback whether to use fallback logic
      # @option error_config [Object] :fallback_result result to return on fallback
      # @return [void]
      #
      # @example Stub batch error handling
      #   stub_batch_error_handling(
      #     batch_instance,
      #     error_config: {
      #       max_retries: 3,
      #       retryable_errors: [StandardError, TimeoutError],
      #       use_fallback: true,
      #       fallback_result: fallback_success_result
      #     }
      #   )
      def stub_batch_error_handling(batch_instance, error_config: {})
        allow(batch_instance).to receive(:max_retries).and_return(error_config[:max_retries]) if error_config[:max_retries]

        allow(batch_instance).to receive(:retryable_errors).and_return(error_config[:retryable_errors]) if error_config[:retryable_errors]

        allow(batch_instance).to receive(:use_fallback?).and_return(error_config[:use_fallback]) if error_config[:use_fallback]

        return unless error_config[:fallback_result]

        allow(batch_instance).to receive(:execute_fallback).and_return(error_config[:fallback_result])
      end

    end
  end
end

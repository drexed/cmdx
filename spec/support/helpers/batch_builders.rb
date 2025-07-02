# frozen_string_literal: true

require "securerandom"

module CMDx
  module Testing
    # Batch builder utilities for creating test batch classes
    #
    # This module provides convenient methods for creating CMDx::Batch classes
    # for testing purposes. While tests can use manual `Class.new(CMDx::Batch)`
    # patterns, these builders offer semantic shortcuts for common batch scenarios
    # and improved semantic clarity.
    #
    # @note These builders are optional - tests can use direct `Class.new(CMDx::Batch)`
    #   for maximum control and transparency, or these builders for convenience
    #   and improved test readability.
    #
    # @example Manual vs Builder Approach
    #   task1 = create_simple_task
    #   task2 = create_failing_task
    #   task3 = create_skipping_task
    #
    #   # Manual approach (explicit, full control)
    #   batch_class = Class.new(CMDx::Batch) do
    #     def self.name
    #       "OrderProcessingBatch"
    #     end
    #
    #     task_settings!(batch_halt: [:failed], tags: [:orders])
    #     process task1
    #     process task2, task3
    #   end
    #
    #   # Builder approach (semantic, convenient)
    #   batch_class = create_simple_batch(
    #     tasks: [task1, task2, task3],
    #     name: "OrderProcessingBatch"
    #   )
    #
    # @example When to Use Manual vs Builder
    #   # Use manual approach when:
    #   # - You need complex batch orchestration
    #   # - You have custom halt conditions or error handling
    #   # - You want maximum transparency in the test
    #   # - You need fine-grained control over task groupings
    #
    #   # Use builder approach when:
    #   # - Testing common batch patterns (sequential, parallel, grouped)
    #   # - You want semantic clarity in test intent
    #   # - You need consistent batch patterns across tests
    #   # - Testing straightforward task execution flows
    #
    # @since 1.0.0
    module BatchBuilders

      # @group Basic Batch Creation

      # Creates a new batch class with optional configuration
      #
      # This is the foundation method for creating CMDx batch classes. It provides
      # a clean interface for creating batch classes with optional naming and
      # custom behavior through block evaluation.
      #
      # @param name [String] name for the batch class (defaults to "AnonymousBatch")
      # @param block [Proc] optional block to evaluate in batch class context
      # @return [Class] new batch class inheriting from CMDx::Batch
      #
      # @example Basic batch class creation
      #   batch_class = create_batch_class do
      #     process create_simple_task
      #     process create_failing_task, create_skipping_task
      #   end
      #
      # @example Named batch class with settings
      #   batch_class = create_batch_class(name: "OrderProcessingBatch") do
      #     task_settings!(batch_halt: [:failed], tags: [:orders])
      #     process create_simple_task(name: "ValidateOrder")
      #     process create_simple_task(name: "ProcessPayment")
      #   end
      #
      # @example Batch class with complex configuration
      #   batch_class = create_batch_class(name: "DataPipelineBatch") do
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
      def create_batch_class(name: "AnonymousBatch", &block)
        batch_class = Class.new(CMDx::Batch)
        batch_class.define_singleton_method(:name) { name }
        batch_class.class_eval(&block) if block_given?
        batch_class
      end

      # Creates a simple sequential batch from an array of tasks
      #
      # This is the most basic batch type, processing tasks one after another
      # in the order specified. Each task runs individually in its own group,
      # ensuring sequential execution with proper dependency handling.
      #
      # @param tasks [Array<Class>] array of task classes to process sequentially
      # @param name [String] name for the batch class (defaults to "SimpleBatch")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] batch class that processes tasks sequentially
      #
      # @example Basic sequential batch
      #   tasks = [
      #     create_simple_task(name: "Step1"),
      #     create_simple_task(name: "Step2"),
      #     create_simple_task(name: "Step3")
      #   ]
      #   batch_class = create_simple_batch(tasks: tasks)
      #   result = batch_class.call
      #   expect(result).to be_success
      #
      # @example Named sequential batch with configuration
      #   tasks = [
      #     create_simple_task(name: "LoadData"),
      #     create_simple_task(name: "ValidateData"),
      #     create_simple_task(name: "SaveData")
      #   ]
      #   batch_class = create_simple_batch(
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
      #   batch_class = create_simple_batch(tasks: tasks)
      #   batch_class.call
      #   expect(execution_order).to eq([:first, :second, :third])
      def create_simple_batch(tasks:, name: "SimpleBatch", &block)
        create_batch_class(name: name) do
          Array(tasks).each { |task| process task }

          class_eval(&block) if block_given?
        end
      end

      # Creates a parallel batch where tasks run concurrently
      #
      # This batch type processes all tasks in a single group, allowing them
      # to run in parallel. Useful for independent operations that can execute
      # simultaneously without dependencies between them.
      #
      # @param tasks [Array<Class>] array of task classes to process in parallel
      # @param name [String] name for the batch class (defaults to "ParallelBatch")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] batch class that processes tasks in parallel
      #
      # @example Basic parallel batch
      #   tasks = [
      #     create_simple_task(name: "FetchUserData"),
      #     create_simple_task(name: "FetchProductData"),
      #     create_simple_task(name: "FetchOrderData")
      #   ]
      #   batch_class = create_parallel_batch(tasks: tasks)
      #   result = batch_class.call
      #   expect(result).to be_success
      #
      # @example Parallel data processing with configuration
      #   tasks = [
      #     create_simple_task(name: "ProcessImages"),
      #     create_simple_task(name: "GenerateThumbnails"),
      #     create_simple_task(name: "ExtractMetadata")
      #   ]
      #   batch_class = create_parallel_batch(
      #     tasks: tasks,
      #     name: "ImageProcessingBatch"
      #   ) do
      #     task_settings!(timeout: 120, tags: [:image_processing, :parallel])
      #   end
      #
      # @example Testing parallel execution with timing
      #   # Tasks that would be slow if run sequentially
      #   tasks = Array.new(3) { create_simple_task }
      #   batch_class = create_parallel_batch(tasks: tasks)
      #
      #   start_time = Time.now
      #   result = batch_class.call
      #   execution_time = Time.now - start_time
      #
      #   expect(result).to be_success
      #   expect(execution_time).to be < 1.0 # Should complete quickly in parallel
      def create_parallel_batch(tasks:, name: "ParallelBatch", &block)
        create_batch_class(name: name) do
          process(*tasks)

          class_eval(&block) if block_given?
        end
      end

      # Creates a grouped batch with custom task groupings
      #
      # This batch type allows you to define custom groups of tasks that run
      # in parallel within each group, while groups themselves run sequentially.
      # This provides fine-grained control over execution flow and dependencies.
      #
      # @param groups [Array<Array<Class>>] array of task groups, where each group contains tasks that run in parallel
      # @param name [String] name for the batch class (defaults to "GroupedBatch")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] batch class with custom task groupings
      #
      # @example Basic grouped batch
      #   batch_class = create_grouped_batch(
      #     groups: [
      #       [create_simple_task(name: "ValidateInput")],                    # Group 1: validation (sequential)
      #       [                                                               # Group 2: processing (parallel)
      #         create_simple_task(name: "ProcessData"),
      #         create_simple_task(name: "SendNotification")
      #       ],
      #       [create_simple_task(name: "Cleanup")]                          # Group 3: cleanup (sequential)
      #     ]
      #   )
      #
      # @example Multi-stage data processing workflow
      #   batch_class = create_grouped_batch(
      #     groups: [
      #       # Stage 1: Data loading and validation (parallel)
      #       [
      #         create_simple_task(name: "LoadFromDatabase"),
      #         create_simple_task(name: "LoadFromAPI")
      #       ],
      #       # Stage 2: Data transformation (parallel)
      #       [
      #         create_simple_task(name: "TransformData"),
      #         create_simple_task(name: "EnrichData"),
      #         create_simple_task(name: "ValidateTransformation")
      #       ],
      #       # Stage 3: Data persistence (sequential)
      #       [create_simple_task(name: "SaveToDatabase")],
      #       # Stage 4: Post-processing (parallel)
      #       [
      #         create_simple_task(name: "UpdateIndex"),
      #         create_simple_task(name: "SendWebhook"),
      #         create_simple_task(name: "GenerateReport")
      #       ]
      #     ],
      #     name: "DataProcessingPipeline"
      #   ) do
      #     task_settings!(timeout: 300, batch_halt: [:failed], tags: [:data_pipeline])
      #   end
      #
      # @example Testing grouped execution flow
      #   execution_log = []
      #
      #   groups = [
      #     # Group 1: runs first, tasks execute in parallel
      #     [
      #       create_task_class { define_method(:call) { sleep(0.1); execution_log << :group1_task1 } },
      #       create_task_class { define_method(:call) { sleep(0.1); execution_log << :group1_task2 } }
      #     ],
      #     # Group 2: runs after group 1 completes
      #     [
      #       create_task_class { define_method(:call) { execution_log << :group2_task1 } }
      #     ]
      #   ]
      #
      #   batch_class = create_grouped_batch(groups: groups)
      #   batch_class.call
      #
      #   # Group 1 tasks can be in any order (parallel), but group 2 comes after
      #   expect(execution_log).to include(:group1_task1, :group1_task2)
      #   expect(execution_log.last).to eq(:group2_task1)
      def create_grouped_batch(groups:, name: "GroupedBatch", &block)
        create_batch_class(name: name) do
          Array(groups).each { |group| process(*group) }

          class_eval(&block) if block_given?
        end
      end

    end
  end
end

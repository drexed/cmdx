# frozen_string_literal: true

module CMDx
  module Testing
    # Task builder utilities for creating test task classes
    #
    # This module provides convenient methods for creating CMDx::Task classes
    # for testing purposes. While tests can use manual `Class.new(CMDx::Task)`
    # patterns, these builders offer semantic shortcuts for common test scenarios.
    #
    # @note These builders are optional - tests can use direct `Class.new(CMDx::Task)`
    #   for maximum control and transparency, or these builders for convenience
    #   and improved semantic clarity.
    #
    # @example Manual vs Builder Approach
    #   # Manual approach (explicit, full control)
    #   task_class = Class.new(CMDx::Task) do
    #     def self.name
    #       "ProcessOrderTask"
    #     end
    #
    #     def call
    #       context.executed = true
    #     end
    #   end
    #
    #   # Builder approach (semantic, convenient)
    #   task_class = create_simple_task(name: "ProcessOrderTask")
    #
    # @example When to Use Manual vs Builder
    #   # Use manual approach when:
    #   # - You need complex custom behavior
    #   # - The test scenario is unique or highly specific
    #   # - You want maximum transparency in the test
    #
    #   # Use builder approach when:
    #   # - Testing common scenarios (success, failure, skip, error)
    #   # - You want semantic clarity in test intent
    #   # - You need consistent test patterns across the codebase
    #
    # @since 1.0.0
    module TaskBuilders

      # @group Basic Task Creation

      # Creates a new task class with optional configuration
      #
      # This is the foundation method for creating CMDx task classes. It provides
      # a clean interface for creating task classes with optional naming and
      # custom behavior through block evaluation.
      #
      # @param base [Class] base class to inherit from (defaults to CMDx::Task)
      # @param name [String] name for the task class (defaults to "AnonymousTask")
      # @param block [Proc] optional block to evaluate in task class context
      # @return [Class] new task class inheriting from CMDx::Task
      #
      # @example Basic task class creation
      #   task_class = create_task_class do
      #     def call
      #       context.message = "Hello World"
      #     end
      #   end
      #
      # @example Named task class with parameters
      #   task_class = create_task_class(name: "MyCustomTask") do
      #     required :input, presence: true
      #
      #     def call
      #       context.output = input.upcase
      #     end
      #   end
      #
      # @example Task class with additional configuration
      #   task_class = create_task_class(name: "ConfiguredTask") do
      #     cmd_settings!(timeout: 30, retries: 3)
      #     optional :debug, type: :boolean, default: false
      #
      #     def call
      #       context.processed = true
      #       context.debug_enabled = debug
      #     end
      #   end
      def create_task_class(base: nil, name: "AnonymousTask", &block)
        task_class = Class.new(base || CMDx::Task)
        task_class.define_singleton_method(:name) do
          hash = rand(10_000).to_s.rjust(4, "0")
          "#{name}#{hash}"
        end
        task_class.class_eval(&block) if block_given?
        task_class
      end

      # Creates a simple task that sets context.executed to true
      #
      # This is the most basic task type, useful for testing task execution
      # flow without complex logic. It simply marks itself as executed and
      # always succeeds.
      #
      # @param base [Class] base class to inherit from (defaults to CMDx::Task)
      # @param name [String] name for the task class (defaults to "SimpleTask")
      # @param block [Proc] optional block for additional configuration
      # @return [Class] task class that sets context.executed = true
      #
      # @example Basic usage
      #   task_class = create_simple_task
      #   result = task_class.call
      #   expect(result).to be_success
      #   expect(result.context.executed).to be(true)
      #
      # @example Named simple task
      #   task_class = create_simple_task(name: "ProcessDataTask")
      #   expect(task_class.name).to eq("ProcessDataTask")
      #
      # @example Simple task with additional behavior
      #   task_class = create_simple_task(name: "NotificationTask") do
      #     optional :email, type: :string
      #
      #     # The call method is already defined to set context.executed = true
      #     # Additional configuration can be added here
      #     cmd_settings!(timeout: 10)
      #   end
      #
      # @example Using in RSpec tests
      #   let(:task_class) { create_simple_task(name: "TestTask") }
      #
      #   it "executes successfully" do
      #     result = task_class.call
      #     expect(result).to be_success
      #     expect(result.context.executed).to be(true)
      #   end
      def create_simple_task(base: nil, name: "SimpleTask", &block)
        create_task_class(name:, base:) do
          define_method :call do
            context.executed = true
          end

          class_eval(&block) if block_given?
        end
      end

      # Alias for create_simple_task where the task is successful
      alias create_successful_task create_simple_task

      # Creates a task that fails with a specific reason and metadata
      #
      # This task type is useful for testing error handling and failure scenarios.
      # It always fails when executed, with customizable failure reason and metadata.
      # The task uses the fail! method, which marks the result as failed without
      # raising an exception.
      #
      # @param base [Class] base class to inherit from (defaults to CMDx::Task)
      # @param name [String] name for the task class (defaults to "FailingTask")
      # @param reason [String] failure reason for the task (defaults to "Task failed")
      # @param metadata [Hash] additional metadata to include in failure
      # @param block [Proc] optional block for additional configuration
      # @return [Class] task class that fails when executed
      #
      # @example Basic failing task
      #   task_class = create_failing_task(reason: "Validation failed")
      #   result = task_class.call
      #   expect(result).to be_failed
      #   expect(result.metadata[:reason]).to eq("Validation failed")
      #
      # @example Failing task with custom metadata
      #   task_class = create_failing_task(
      #     name: "PaymentTask",
      #     reason: "Payment declined",
      #     code: "PAY_001",
      #     retry_after: 30
      #   )
      #   result = task_class.call
      #   expect(result).to be_failed
      #   expect(result.metadata[:reason]).to eq("Payment declined")
      #   expect(result.metadata[:code]).to eq("PAY_001")
      #   expect(result.metadata[:retry_after]).to eq(30)
      #
      # @example Failing task with additional configuration
      #   task_class = create_failing_task(name: "ValidationTask") do
      #     required :data, type: :hash
      #     cmd_settings!(tags: [:validation, :critical])
      #   end
      #
      # @example Comparing with create_erroring_task
      #   # This uses fail! method (always results in failed status, no exception)
      #   failing_task = create_failing_task(reason: "Validation error")
      #   result = failing_task.call
      #   expect(result).to be_failed  # No exception raised
      #
      #   # This raises an exception (caught by perform, propagated by call!)
      #   erroring_task = create_erroring_task(reason: "System error")
      #   expect { erroring_task.call! }.to raise_error(StandardError)
      def create_failing_task(base: nil, name: "FailingTask", reason: "Task failed", **metadata, &block)
        create_task_class(name:, base:) do
          define_method :call do
            fail!(reason: reason, **metadata)
          end

          class_eval(&block) if block_given?
        end
      end

      # Creates a task that skips execution with a specific reason and metadata
      #
      # This task type is useful for testing skip scenarios and conditional
      # execution paths. It always skips when executed, marking the result
      # as skipped rather than failed or successful.
      #
      # @param base [Class] base class to inherit from (defaults to CMDx::Task)
      # @param name [String] name for the task class (defaults to "SkippingTask")
      # @param reason [String] skip reason for the task (defaults to "Task skipped")
      # @param metadata [Hash] additional metadata to include in skip
      # @param block [Proc] optional block for additional configuration
      # @return [Class] task class that skips when executed
      #
      # @example Basic skipping task
      #   task_class = create_skipping_task(reason: "Feature disabled")
      #   result = task_class.call
      #   expect(result).to be_skipped
      #   expect(result.metadata[:reason]).to eq("Feature disabled")
      #
      # @example Skipping task with metadata
      #   task_class = create_skipping_task(
      #     name: "MaintenanceTask",
      #     reason: "Maintenance mode",
      #     maintenance_until: "2024-01-01T10:00:00Z",
      #     retry_after: 3600
      #   )
      #   result = task_class.call
      #   expect(result).to be_skipped
      #   expect(result.metadata[:maintenance_until]).to eq("2024-01-01T10:00:00Z")
      #   expect(result.metadata[:retry_after]).to eq(3600)
      #
      # @example Conditional skipping logic testing
      #   task_class = create_skipping_task(name: "ConditionalTask") do
      #     optional :should_process, type: :boolean, default: false
      #     # Skip logic is already defined, but you can add conditions here
      #   end
      def create_skipping_task(base: nil, name: "SkippingTask", reason: "Task skipped", **metadata, &block)
        create_task_class(name:, base:) do
          define_method :call do
            skip!(reason: reason, **metadata)
          end

          class_eval(&block) if block_given?
        end
      end

      # Creates a task that raises an exception with a specific reason
      #
      # This task type is useful for testing exception handling and error
      # propagation scenarios. It always raises a StandardError when executed,
      # which differs from create_failing_task that uses the fail! method.
      #
      # When using perform(), the exception is caught and the result is marked as failed.
      # When using call!() or perform!(), the exception propagates to the caller.
      #
      # @param base [Class] base class to inherit from (defaults to CMDx::Task)
      # @param name [String] name for the task class (defaults to "ErroringTask")
      # @param reason [String] error message for the raised exception (defaults to "Task errored")
      # @param metadata [Hash] additional metadata (reserved for future use)
      # @param block [Proc] optional block for additional configuration
      # @return [Class] task class that raises StandardError when executed
      #
      # @example Basic erroring task
      #   task_class = create_erroring_task(reason: "Database connection failed")
      #   expect { task_class.call! }.to raise_error(StandardError, "Database connection failed")
      #
      # @example Testing exception handling in perform vs call!
      #   task_class = create_erroring_task(name: "NetworkTask", reason: "Network timeout")
      #
      #   # perform catches exceptions and marks result as failed
      #   instance = task_class.new
      #   instance.process
      #   expect(instance.result).to be_failed
      #   expect(instance.result.metadata[:reason]).to include("Network timeout")
      #
      #   # call! propagates exceptions
      #   expect { task_class.call! }.to raise_error(StandardError, "Network timeout")
      #
      # @example Erroring task with additional configuration
      #   task_class = create_erroring_task(name: "DatabaseTask") do
      #     required :connection_string, type: :string
      #     cmd_settings!(timeout: 5, retries: 3)
      #   end
      #
      # @example Comparing different error scenarios
      #   # Raises an exception (caught by perform, propagated by call!)
      #   erroring_task = create_erroring_task(reason: "System error")
      #   expect { erroring_task.call! }.to raise_error(StandardError)
      #
      #   # Uses fail! method (always results in failed status, no exception)
      #   failing_task = create_failing_task(reason: "Validation error")
      #   result = failing_task.call
      #   expect(result).to be_failed
      def create_erroring_task(base: nil, name: "ErroringTask", reason: "Task errored", **_metadata, &block)
        create_task_class(name:, base:) do
          define_method :call do
            raise StandardError, reason
          end

          class_eval(&block) if block_given?
        end
      end

    end
  end
end

# frozen_string_literal: true

require "securerandom"

module CMDx
  module Testing
    # Task testing helpers for mocking, stubbing, and creating test doubles
    #
    # This module provides comprehensive helper methods for testing CMDx tasks,
    # results, chains, and related components. It includes methods for creating
    # mock objects, stubbing external dependencies, and building test scenarios.
    #
    # @example Basic usage
    #   RSpec.describe MyTask do
    #     it "processes successfully" do
    #       task = mock_task
    #       result = mock_success_result(task: task)
    #       expect(result).to be_success
    #     end
    #   end
    module TaskHelpers

      # @group Double Creation Methods

      # Creates a mock task double with realistic defaults
      #
      # This method creates a comprehensive task double that includes all the
      # standard task attributes and relationships. It's useful for testing
      # scenarios where you need a task object but don't want to create an
      # actual task class.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [String] :id task identifier
      # @option overrides [Class] :class task class double
      # @option overrides [Object] :chain associated chain
      # @option overrides [Object] :context task context
      # @option overrides [Object] :result task result
      # @option overrides [Object] :errors task errors collection
      # @option overrides [Object] :cmd_middlewares middleware registry
      # @option overrides [Object] :cmd_callbacks callback registry
      # @option overrides [Object] :cmd_parameters parameter registry
      #
      # @return [RSpec::Mocks::Double] configured task double
      #
      # @example Basic task mock
      #   task = mock_task
      #   expect(task.id).to match(/^test-task-/)
      #
      # @example Task mock with custom attributes
      #   task = mock_task(id: "custom-id", class: MyTaskClass)
      #   expect(task.id).to eq("custom-id")
      def mock_task(overrides = {})
        defaults = {
          id: "test-task-#{SecureRandom.hex(4)}",
          class: double("TaskClass", name: "TestTask"),
          chain: mock_chain,
          context: mock_context,
          result: mock_result,
          errors: double("Errors", empty?: true, full_messages: [], messages: {}),
          cmd_middlewares: double("MiddlewareRegistry"),
          cmd_callbacks: double("CallbackRegistry"),
          cmd_parameters: double("ParameterRegistry")
        }

        double("Task", defaults.merge(overrides))
      end

      # Creates a mock result double with realistic defaults
      #
      # This method creates a result double that represents the outcome of task
      # execution. It includes all standard result attributes and status methods.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [Object] :task associated task
      # @option overrides [Object] :chain associated chain
      # @option overrides [Object] :context result context
      # @option overrides [String] :status result status ("success", "failed", "skipped")
      # @option overrides [String] :state execution state
      # @option overrides [String] :outcome final outcome
      # @option overrides [Integer] :runtime execution time in milliseconds
      # @option overrides [Hash] :metadata additional result metadata
      # @option overrides [Integer] :index position in chain
      # @option overrides [Boolean] :executed? whether task was executed
      # @option overrides [Boolean] :success? whether result is successful
      # @option overrides [Boolean] :failed? whether result is failed
      # @option overrides [Boolean] :skipped? whether result is skipped
      #
      # @return [RSpec::Mocks::Double] configured result double
      #
      # @example Basic result mock
      #   result = mock_result
      #   expect(result).to be_success
      #
      # @example Failed result mock
      #   result = mock_result(status: "failed", success?: false, failed?: true)
      #   expect(result).to be_failed
      def mock_result(overrides = {})
        defaults = {
          task: nil,
          chain: mock_chain,
          context: mock_context,
          status: "success",
          state: "executed",
          outcome: "success",
          runtime: 0,
          metadata: {},
          index: 0,
          executed?: true,
          success?: true,
          failed?: false,
          skipped?: false
        }

        double("Result", defaults.merge(overrides))
      end

      # Creates a mock chain double with realistic defaults
      #
      # This method creates a chain double that represents a collection of
      # task execution results. It includes standard chain attributes and
      # collection methods.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [String] :id chain identifier
      # @option overrides [Integer] :index current position
      # @option overrides [Array] :results collection of results
      # @option overrides [Integer] :size chain size
      # @option overrides [Object] :first first result
      # @option overrides [Object] :last last result
      # @option overrides [String] :state chain state
      # @option overrides [String] :status overall status
      # @option overrides [String] :outcome final outcome
      # @option overrides [Integer] :runtime total execution time
      #
      # @return [RSpec::Mocks::Double] configured chain double
      #
      # @example Basic chain mock
      #   chain = mock_chain
      #   expect(chain.status).to eq("success")
      #
      # @example Chain with results
      #   chain = mock_chain(results: [result1, result2], size: 2)
      #   expect(chain.size).to eq(2)
      def mock_chain(overrides = {})
        defaults = {
          id: "test-chain-#{SecureRandom.hex(4)}",
          index: 0,
          results: [],
          size: 0,
          first: nil,
          last: nil,
          state: "complete",
          status: "success",
          outcome: "success",
          runtime: 0
        }

        double("Chain", defaults.merge(overrides))
      end

      # Creates a flexible mock context double
      #
      # This method creates a context double that accepts any method calls
      # and returns nil by default, while allowing specific attributes to
      # be configured with custom return values.
      #
      # @param attributes [Hash] specific attributes to configure
      # @return [RSpec::Mocks::Double] configured context double
      #
      # @example Basic context mock
      #   context = mock_context
      #   expect(context.any_attribute).to be_nil
      #
      # @example Context with specific attributes
      #   context = mock_context(user_id: 123, email: "test@example.com")
      #   expect(context.user_id).to eq(123)
      #   expect(context.email).to eq("test@example.com")
      def mock_context(attributes = {})
        context = double("Context")

        # Allow any method to be called on context and return nil by default
        allow(context).to receive(:method_missing).and_return(nil)

        # Set specific attributes if provided
        attributes.each do |key, value|
          allow(context).to receive(key).and_return(value)
        end

        context
      end

      # Creates a mock parameter double with realistic defaults
      #
      # This method creates a parameter double that represents a task parameter
      # definition, including validation state and serialization methods.
      #
      # @param overrides [Hash] attributes to override defaults
      # @option overrides [Symbol] :name parameter name
      # @option overrides [Symbol] :type parameter type
      # @option overrides [Boolean] :required whether parameter is required
      # @option overrides [Boolean] :valid? validation state
      # @option overrides [Symbol] :method_name accessor method name
      # @option overrides [Array] :children nested parameters
      # @option overrides [String] :to_s string representation
      # @option overrides [Hash] :to_h hash representation
      #
      # @return [RSpec::Mocks::Double] configured parameter double
      #
      # @example Basic parameter mock
      #   param = mock_parameter
      #   expect(param.name).to eq(:test_param)
      #
      # @example Required parameter mock
      #   param = mock_parameter(name: :user_id, type: :integer, required: true)
      #   expect(param).to be_required
      def mock_parameter(overrides = {})
        defaults = {
          name: :test_param,
          type: :string,
          required: false,
          valid?: true,
          method_name: :test_param,
          children: [],
          to_s: "Parameter: name=test_param type=string required=false",
          to_h: { name: :test_param, type: :string, required: false }
        }

        double("Parameter", defaults.merge(overrides))
      end

      # Creates a mock logger double with all log level methods stubbed
      #
      # This method creates a logger double that responds to all standard
      # logging methods (debug, info, warn, error, fatal) without raising errors.
      #
      # @return [RSpec::Mocks::Double] configured logger double
      #
      # @example Basic logger mock
      #   logger = mock_logger
      #   logger.info("Test message")  # Won't raise error
      #   logger.error("Error message")  # Won't raise error
      def mock_logger
        logger = double("Logger")
        allow(logger).to receive(:debug)
        allow(logger).to receive(:info)
        allow(logger).to receive(:warn)
        allow(logger).to receive(:error)
        allow(logger).to receive(:fatal)
        logger
      end

      # @group Stubbing Helper Methods

      # Stubs both TaskSerializer and ResultSerializer calls
      #
      # This method provides a convenient way to stub serializer calls for
      # both tasks and results simultaneously, useful in tests that involve
      # both types of serialization.
      #
      # @param task_data [Hash] data to return from TaskSerializer
      # @param result_data [Hash] data to return from ResultSerializer
      # @return [void]
      #
      # @example Stub both serializers
      #   stub_task_serializers(
      #     task_data: { id: "task-1", name: "MyTask" },
      #     result_data: { status: "success", runtime: 100 }
      #   )
      def stub_task_serializers(task_data: {}, result_data: {})
        allow(CMDx::TaskSerializer).to receive(:call).and_return(task_data) unless task_data.empty?
        allow(CMDx::ResultSerializer).to receive(:call).and_return(result_data) unless result_data.empty?
      end

      # Stubs TaskSerializer calls to return specific data
      #
      # @param return_value [Hash] data to return from TaskSerializer.call
      # @return [void]
      #
      # @example Stub task serializer
      #   stub_task_serializer({ id: "task-1", class: "MyTask" })
      def stub_task_serializer(return_value = {})
        allow(CMDx::TaskSerializer).to receive(:call).and_return(return_value)
      end

      # Stubs LoggerSerializer calls to return specific data
      #
      # @param data [Hash] data to return from LoggerSerializer.call
      # @return [void]
      #
      # @example Stub logger serializer
      #   stub_logger_serializer({ timestamp: "2023-01-01", level: "info" })
      def stub_logger_serializer(data = {})
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(data)
      end

      # Stubs time-related utility methods for consistent test output
      #
      # This method stubs both timestamp generation and process ID retrieval
      # to ensure consistent output in tests that involve time-sensitive logging.
      #
      # @param timestamp [String] timestamp to return from LogTimestamp.call
      # @param pid [Integer] process ID to return from Process.pid
      # @return [void]
      #
      # @example Stub time helpers
      #   stub_time_helpers(timestamp: "2023-01-01T10:00:00", pid: 9999)
      def stub_time_helpers(timestamp: "2022-07-17T18:43:15.123456", pid: 1234)
        allow(CMDx::Utils::LogTimestamp).to receive(:call).and_return(timestamp)
        allow(Process).to receive(:pid).and_return(pid)
      end

      # Stubs ANSI color utility methods for consistent test output
      #
      # This method stubs color formatting methods to prevent ANSI escape codes
      # from interfering with test output while allowing color-related logic to
      # be tested.
      #
      # @param color [String] default color to return from AnsiColor.call
      # @param result_colors [Hash] specific color mappings for ResultAnsi.call
      # @return [void]
      #
      # @example Basic color stubbing
      #   stub_ansi_colors(color: "red_text")
      #
      # @example Specific result color mappings
      #   stub_ansi_colors(
      #     color: "default",
      #     result_colors: { "SUCCESS" => "green_success", "FAILED" => "red_failed" }
      #   )
      def stub_ansi_colors(color: "colored_text", result_colors: {})
        allow(CMDx::Utils::AnsiColor).to receive(:call).and_return(color)

        if result_colors.any?
          result_colors.each do |value, colorized_value|
            allow(CMDx::ResultAnsi).to receive(:call).with(value).and_return(colorized_value)
          end
        else
          allow(CMDx::ResultAnsi).to receive(:call).and_return(color)
        end
      end

      # Stubs Correlator methods for correlation ID management
      #
      # This method stubs correlator behavior to provide consistent correlation
      # IDs in tests and prevent interference with correlation tracking.
      #
      # @param overrides [Hash] additional methods to stub on Correlator
      # @return [void]
      #
      # @example Basic correlator stubbing
      #   stub_correlator
      #
      # @example Custom correlation ID
      #   stub_correlator(current_id: "custom-correlation-id")
      def stub_correlator(overrides = {})
        allow(CMDx::Correlator).to receive(:use).and_yield
        allow(CMDx::Correlator).to receive(:current_id).and_return("test-correlation-id")

        overrides.each do |method, value|
          allow(CMDx::Correlator).to receive(method).and_return(value)
        end
      end

      # Stubs fault class constants for testing fault scenarios
      #
      # This method creates temporary fault class constants that inherit from
      # CMDx::Fault, useful for testing fault handling without defining actual
      # fault classes.
      #
      # @param fault_classes [Array<String>] names of fault classes to stub
      # @return [void]
      #
      # @example Stub fault classes
      #   stub_fault_classes("ValidationFault", "NetworkFault")
      #   # Now CMDx::ValidationFault and CMDx::NetworkFault are available
      def stub_fault_classes(*fault_classes)
        fault_classes.each do |fault_class|
          stub_const("CMDx::#{fault_class}", Class.new(CMDx::Fault))
        end
      end

      # Stubs task condition evaluation methods
      #
      # This method stubs internal task condition evaluation methods to control
      # whether tasks should execute based on their conditions.
      #
      # @param task [Object] task object to stub methods on
      # @param conditions_result [Boolean] result of condition evaluation
      # @return [void]
      #
      # @example Allow task execution
      #   stub_task_conditions(task, true)
      #
      # @example Prevent task execution
      #   stub_task_conditions(task, false)
      def stub_task_conditions(task, conditions_result = true)
        allow(task).to receive(:__cmdx_eval).and_return(conditions_result)
        allow(task).to receive(:__cmdx_try)
      end

      # @group Result State Builders

      # Creates a mock result in successful state
      #
      # This is a convenience method for creating result doubles that represent
      # successful task execution with all appropriate attributes set.
      #
      # @param task [Object] task to associate with result (creates mock if nil)
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured success result double
      #
      # @example Basic success result
      #   result = mock_success_result
      #   expect(result).to be_success
      #
      # @example Success result with custom task
      #   result = mock_success_result(task: my_task, runtime: 150)
      #   expect(result.runtime).to eq(150)
      def mock_success_result(task: nil, **attributes)
        result_attributes = {
          status: "success",
          state: "executed",
          outcome: "success",
          executed?: true,
          success?: true,
          failed?: false,
          skipped?: false
        }.merge(attributes)

        task ||= mock_task
        result_attributes[:task] = task
        mock_result(result_attributes)
      end

      # Creates a mock result in failed state
      #
      # This is a convenience method for creating result doubles that represent
      # failed task execution with appropriate failure metadata.
      #
      # @param task [Object] task to associate with result (creates mock if nil)
      # @param reason [String] failure reason for metadata
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured failed result double
      #
      # @example Basic failed result
      #   result = mock_failed_result
      #   expect(result).to be_failed
      #
      # @example Failed result with custom reason
      #   result = mock_failed_result(reason: "Validation error", runtime: 50)
      #   expect(result.metadata[:reason]).to eq("Validation error")
      def mock_failed_result(task: nil, reason: "Test failure", **attributes)
        result_attributes = {
          status: "failed",
          state: "executed",
          outcome: "failed",
          executed?: true,
          success?: false,
          failed?: true,
          skipped?: false,
          metadata: { reason: reason }
        }.merge(attributes)

        task ||= mock_task
        result_attributes[:task] = task
        mock_result(result_attributes)
      end

      # Creates a mock result in skipped state
      #
      # This is a convenience method for creating result doubles that represent
      # skipped task execution with appropriate skip metadata.
      #
      # @param task [Object] task to associate with result (creates mock if nil)
      # @param reason [String] skip reason for metadata
      # @param attributes [Hash] additional attributes to merge
      # @return [RSpec::Mocks::Double] configured skipped result double
      #
      # @example Basic skipped result
      #   result = mock_skipped_result
      #   expect(result).to be_skipped
      #
      # @example Skipped result with custom reason
      #   result = mock_skipped_result(reason: "Condition not met")
      #   expect(result.metadata[:reason]).to eq("Condition not met")
      def mock_skipped_result(task: nil, reason: "Test skip", **attributes)
        result_attributes = {
          status: "skipped",
          state: "executed",
          outcome: "skipped",
          executed?: true,
          success?: false,
          failed?: false,
          skipped?: true,
          metadata: { reason: reason }
        }.merge(attributes)

        task ||= mock_task
        result_attributes[:task] = task
        mock_result(result_attributes)
      end

      # @group Parameter Value Stubbing

      # Stubs parameter value creation and evaluation
      #
      # This method stubs the ParameterValue class to return a specific value
      # when parameter values are evaluated, useful for testing parameter
      # processing without complex setup.
      #
      # @param task [Object] task object for parameter context
      # @param value [Object] value to return from parameter evaluation
      # @return [void]
      #
      # @example Stub parameter value
      #   stub_parameter_value(task, "stubbed_value")
      def stub_parameter_value(task, value)
        parameter_value = double("ParameterValue")
        allow(CMDx::ParameterValue).to receive(:new).with(task, anything).and_return(parameter_value)
        allow(parameter_value).to receive(:call).and_return(value)
      end

      # @group Callback and Middleware Helpers

      # Stubs callback execution behavior
      #
      # This method stubs callback-related methods to control callback execution
      # during testing, allowing you to test scenarios with or without
      # callback execution.
      #
      # @param callback_instance [Object] callback instance to stub
      # @param should_execute [Boolean] whether callback should execute
      # @return [void]
      #
      # @example Allow callback execution
      #   stub_callback_execution(my_callback, should_execute: true)
      #
      # @example Prevent callback execution
      #   stub_callback_execution(my_callback, should_execute: false)
      def stub_callback_execution(callback_instance, should_execute: true)
        allow(callback_instance).to receive(:is_a?).with(CMDx::Callback).and_return(true)
        allow(callback_instance).to receive(:call) if should_execute
      end

      # Stubs middleware execution behavior
      #
      # This method stubs middleware call behavior to pass through to the
      # next callable in the middleware chain, useful for testing middleware
      # integration without complex setup.
      #
      # @param middleware_instance [Object] middleware instance to stub
      # @return [void]
      #
      # @example Stub middleware execution
      #   stub_middleware_execution(my_middleware)
      def stub_middleware_execution(middleware_instance)
        allow(middleware_instance).to receive(:call) do |task, callable|
          callable.call(task)
        end
      end

    end
  end
end

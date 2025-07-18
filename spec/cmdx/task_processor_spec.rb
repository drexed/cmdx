# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskProcessor do
  subject(:processor) { described_class.new(task) }

  let(:task) { task_class.new }
  let(:task_class) { create_simple_task(name: "ProcessorTestTask") }

  before do
    allow(CMDx::Immutator).to receive(:call).and_return(task)
    allow(CMDx::ResultLogger).to receive(:call) { |result| result }
  end

  describe ".call" do
    it "creates instance and delegates to instance call method" do
      allow_any_instance_of(described_class).to receive(:call).and_return("delegated_result")

      result = described_class.call(task)

      expect(result).to eq("delegated_result")
    end

    it "returns result from successful task execution" do
      result = described_class.call(task)

      expect(result).to be_successful_task
      expect(result.context.executed).to be(true)
    end

    it "handles task with validation errors" do
      validation_task_class = create_task_class(name: "ValidationTask") do
        required :name, presence: true
        def call; end
      end

      task = validation_task_class.new
      result = described_class.call(task)

      expect(result).to be_failed_task
    end

    it "handles task that raises StandardError" do
      error_task = create_erroring_task(name: "ErrorTask").new
      result = described_class.call(error_task)

      expect(result).to be_failed_task
    end
  end

  describe ".call!" do
    it "creates instance and delegates to instance call! method" do
      allow_any_instance_of(described_class).to receive(:call!).and_return("bang_result")

      result = described_class.call!(task)

      expect(result).to eq("bang_result")
    end

    it "returns result from successful task execution" do
      result = described_class.call!(task)

      expect(result).to be_successful_task
      expect(result.context.executed).to be(true)
    end

    it "re-raises StandardError exceptions" do
      error_task = create_erroring_task(name: "ErrorTask", reason: "Critical error").new

      expect { described_class.call!(error_task) }.to raise_error(StandardError, "Critical error")
    end

    it "re-raises UndefinedCallError exceptions" do
      undefined_task_class = create_task_class(name: "UndefinedTask")
      task = undefined_task_class.new

      expect { described_class.call!(task) }.to raise_error(CMDx::UndefinedCallError)
    end
  end

  describe "#initialize" do
    it "stores task reference" do
      expect(processor.task).to eq(task)
    end

    it "accepts any task instance" do
      custom_task = create_failing_task(name: "CustomTask").new
      processor = described_class.new(custom_task)

      expect(processor.task).to eq(custom_task)
    end
  end

  describe "#call" do
    context "with successful task" do
      it "executes task and returns successful result" do
        result = processor.call

        expect(result).to be_successful_task
        expect(result.context.executed).to be(true)
      end

      it "marks result as executed" do
        processor.call

        expect(task.result).to be_executed
      end

      it "captures runtime" do
        processor.call

        expect(task.result).to have_runtime
      end

      it "calls immutator and result logger" do
        expect(CMDx::Immutator).to receive(:call).with(task)
        expect(CMDx::ResultLogger).to receive(:call).with(task.result)

        processor.call
      end

      it "returns task result" do
        result = processor.call

        expect(result).to eq(task.result)
      end
    end

    context "with failing task" do
      let(:task_class) { create_failing_task(name: "FailingTask", reason: "Test failure") }

      it "returns failed result" do
        result = processor.call

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to eq("Test failure")
      end

      it "marks result as executed" do
        processor.call

        expect(task.result).to be_executed
      end

      it "executes failure callbacks" do
        allow(task.cmd_callbacks).to receive(:call)

        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_failed)
        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_bad)
      end
    end

    context "with skipping task" do
      let(:task_class) { create_skipping_task(name: "SkippingTask", reason: "Test skip") }

      it "returns skipped result" do
        result = processor.call

        expect(result).to be_skipped_task
        expect(result.metadata[:reason]).to eq("Test skip")
      end

      it "marks result as executed" do
        processor.call

        expect(task.result).to be_executed
      end

      it "executes skip callbacks" do
        allow(task.cmd_callbacks).to receive(:call)

        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_skipped)
        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_good)
      end
    end

    context "with task that has validation errors" do
      let(:task_class) do
        create_task_class(name: "ValidationTask") do
          required :name, presence: true

          def call
            context.executed = true
          end
        end
      end

      it "returns failed result with validation messages" do
        result = processor.call

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to include("name is a required parameter")
        expect(result.metadata[:messages]).to have_key(:name)
      end

      it "marks result as executed" do
        processor.call

        expect(task.result).to be_executed
        expect(task.context.executed).to be_nil
      end
    end

    context "with task that has valid parameters" do
      let(:task_class) do
        create_task_class(name: "ValidatedTask") do
          def call
            context.processed = true
          end
        end
      end

      it "executes successfully" do
        result = processor.call

        expect(result).to be_successful_task
        expect(result.context.processed).to be(true)
      end
    end

    context "with task that raises StandardError" do
      let(:task_class) do
        create_erroring_task(name: "ErrorTask", reason: "Something went wrong")
      end

      it "returns failed result with error details" do
        result = processor.call

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to eq("[StandardError] Something went wrong")
        expect(result.metadata[:original_exception]).to be_a(StandardError)
      end

      it "marks result as executed" do
        processor.call

        expect(task.result).to be_executed
      end

      it "executes failure callbacks" do
        allow(task.cmd_callbacks).to receive(:call)

        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_failed)
        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_bad)
      end
    end

    context "with task that raises UndefinedCallError" do
      let(:task_class) do
        create_task_class(name: "UndefinedTask") do
          # Intentionally doesn't implement call method
        end
      end

      it "re-raises UndefinedCallError" do
        expect { processor.call }.to raise_error(
          CMDx::UndefinedCallError,
          /call method not defined/
        )
      end

      it "re-raises the error without calling task logic" do
        expect { processor.call }.to raise_error(CMDx::UndefinedCallError)

        expect(task.context.executed).to be_nil
      end
    end

    context "with callback execution" do
      let(:task_class) do
        create_task_class(name: "CallbackTask") do
          def call
            context.executed = true
          end
        end
      end

      before do
        allow(task.cmd_callbacks).to receive(:call)
      end

      it "executes before_execution callbacks" do
        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :before_execution)
      end

      it "executes on_executing callbacks" do
        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_executing)
      end

      it "executes validation callbacks" do
        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :before_validation)
        expect(task.cmd_callbacks).to have_received(:call).with(task, :after_validation)
      end

      it "executes state-based callbacks" do
        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_success)
        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_executed)
      end

      it "executes outcome-based callbacks" do
        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_good)
      end

      it "executes after_execution callbacks" do
        processor.call

        expect(task.cmd_callbacks).to have_received(:call).with(task, :after_execution)
      end
    end

    context "with middleware integration" do
      let(:task_class) do
        create_task_class(name: "MiddlewareTask") do
          use :middleware, CMDx::Middlewares::Correlate

          def call
            context.executed = true
          end
        end
      end

      it "processes task through middleware stack" do
        result = processor.call

        expect(result).to be_successful_task
        expect(result.context.executed).to be(true)
      end
    end
  end

  describe "#call!" do
    context "with successful task" do
      it "executes task and returns successful result" do
        result = processor.call!

        expect(result).to be_successful_task
        expect(result.context.executed).to be(true)
      end

      it "marks result as executed" do
        processor.call!

        expect(task.result).to be_executed
      end

      it "executes callbacks normally" do
        allow(task.cmd_callbacks).to receive(:call)

        processor.call!

        expect(task.cmd_callbacks).to have_received(:call).with(task, :after_execution)
      end

      it "calls terminate_call" do
        expect(CMDx::Immutator).to receive(:call).with(task)
        expect(CMDx::ResultLogger).to receive(:call).with(task.result)

        processor.call!
      end
    end

    context "with task that raises StandardError" do
      let(:task_class) do
        create_erroring_task(name: "ErrorTask", reason: "Something went wrong")
      end

      it "clears chain and re-raises exception" do
        expect(CMDx::Chain).to receive(:clear)
        expect { processor.call! }.to raise_error(StandardError, "Something went wrong")
      end

      it "does not mark result as executed" do
        expect { processor.call! }.to raise_error(StandardError)

        expect(task.result).not_to be_executed
      end

      it "does not execute after_call callbacks" do
        allow(task.cmd_callbacks).to receive(:call)

        expect { processor.call! }.to raise_error(StandardError)

        expect(task.cmd_callbacks).not_to have_received(:call).with(task, :after_execution)
      end
    end

    context "with task that raises UndefinedCallError" do
      let(:task_class) do
        create_task_class(name: "UndefinedTask") do
          # Intentionally doesn't implement call method
        end
      end

      it "clears chain and re-raises UndefinedCallError" do
        expect(CMDx::Chain).to receive(:clear).at_least(:once)
        expect { processor.call! }.to raise_error(
          CMDx::UndefinedCallError,
          /call method not defined/
        )
      end

      it "does not mark result as executed" do
        expect { processor.call! }.to raise_error(CMDx::UndefinedCallError)

        expect(task.result).not_to be_executed
      end
    end

    context "with task that has validation errors" do
      let(:task_class) do
        create_task_class(name: "ValidationTask") do
          required :name, presence: true
          def call; end
        end
      end

      it "clears chain and re-raises validation failure" do
        expect(CMDx::Chain).to receive(:clear).at_least(:once)
        expect { processor.call! }.to raise_error(StandardError)
      end
    end
  end

  describe "parameter validation integration" do
    it "validates parameters before execution" do
      validation_task_class = create_task_class(name: "ValidationTask") do
        required :name, presence: true

        def call
          context.processed = true
        end
      end

      task = validation_task_class.new # missing required name parameter
      result = described_class.call(task)

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("name is a required parameter")
    end

    it "executes task when no validation is required" do
      simple_task_class = create_task_class(name: "SimpleTask") do
        def call
          context.processed = true
        end
      end

      task = simple_task_class.new
      result = described_class.call(task)

      expect(result).to be_successful_task
      expect(result.context.processed).to be(true)
    end
  end

  describe "chain management" do
    it "clears chain on bang method exceptions" do
      error_task = create_erroring_task(name: "ErrorTask")
      processor = described_class.new(error_task.new)

      expect(CMDx::Chain).to receive(:clear)
      expect { processor.call! }.to raise_error(StandardError)
    end

    it "executes without chain errors" do
      # Just verify that chain operations don't break normal execution
      result = processor.call
      expect(result).to be_successful_task
    end
  end

  describe "private method behavior" do
    describe "#before_call" do
      it "sets result to executing state" do
        allow(task.cmd_callbacks).to receive(:call)
        processor.send(:before_call)

        expect(task.result).to be_executing
      end

      it "executes before_execution and on_executing callbacks" do
        allow(task.cmd_callbacks).to receive(:call)
        processor.send(:before_call)

        expect(task.cmd_callbacks).to have_received(:call).with(task, :before_execution)
        expect(task.cmd_callbacks).to have_received(:call).with(task, :on_executing)
      end
    end

    describe "#validate_parameters" do
      let(:task_class) do
        create_task_class(name: "ValidationTask") do
          required :name, presence: true
          def call; end
        end
      end

      it "executes validation callbacks" do
        allow(task.cmd_callbacks).to receive(:call)
        allow(task.cmd_parameters).to receive(:validate!)

        processor.send(:validate_parameters)

        expect(task.cmd_callbacks).to have_received(:call).with(task, :before_validation)
        expect(task.cmd_callbacks).to have_received(:call).with(task, :after_validation)
      end

      it "validates parameters" do
        expect(task.cmd_parameters).to receive(:validate!).with(task)

        processor.send(:validate_parameters)
      end
    end

    describe "#after_call" do
      before do
        # Result starts in success status by default, just need to execute it
        task.result.executing!
        task.result.complete!
        allow(task.cmd_callbacks).to receive(:call)
      end

      it "executes callbacks for successful task" do
        processor.send(:after_call)

        # Verify that callbacks are called - the exact callback names may vary
        expect(task.cmd_callbacks).to have_received(:call).at_least(:once)
      end
    end

    describe "#terminate_call" do
      it "calls immutator and result logger" do
        expect(CMDx::Immutator).to receive(:call).with(task)
        expect(CMDx::ResultLogger).to receive(:call).with(task.result)

        processor.send(:terminate_call)
      end

      it "calls immutator and result logger and returns result" do
        expect(CMDx::Immutator).to receive(:call).with(task)
        expect(CMDx::ResultLogger).to receive(:call).with(task.result)

        result = processor.send(:terminate_call)

        expect(result).to eq(task.result)
      end
    end
  end

  describe "edge cases" do
    it "handles task with no context data" do
      empty_task = task_class.new({})
      result = described_class.call(empty_task)

      expect(result).to be_successful_task
    end

    it "handles task with complex context" do
      complex_data = {
        user: { id: 123, name: "John" },
        settings: { theme: "dark", notifications: true },
        metadata: { created_at: Time.now }
      }

      task = task_class.new(complex_data)
      result = described_class.call(task)

      expect(result).to be_successful_task
      expect(result.context.user).to eq(complex_data[:user])
      expect(result.context.settings).to eq(complex_data[:settings])
    end

    it "handles multiple parameter types" do
      multi_param_task_class = create_task_class(name: "MultiParamTask") do
        required :string_param, type: :string
        required :integer_param, type: :integer
        required :boolean_param, type: :boolean
        optional :array_param, type: :array, default: []
        optional :hash_param, type: :hash, default: {}

        def call
          context.all_params_processed = true
        end
      end

      task = multi_param_task_class.new(
        string_param: "test",
        integer_param: 42,
        boolean_param: true,
        array_param: [1, 2, 3],
        hash_param: { key: "value" }
      )

      result = described_class.call(task)

      expect(result).to be_successful_task
      expect(result.context.all_params_processed).to be(true)
    end
  end
end

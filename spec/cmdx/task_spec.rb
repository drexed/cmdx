# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  let(:task_class) do
    create_simple_task
  end

  describe ".call" do
    it "creates a new instance and calls perform" do
      result = task_class.call

      expect(result).to be_a(CMDx::Result)
    end

    it "passes arguments to new instance" do
      params = { user_id: 123, name: "Test" }
      result = task_class.call(params)

      expect(result.context.user_id).to eq(123)
      expect(result.context.name).to eq("Test")
    end

    it "returns result object" do
      result = task_class.call

      expect(result).to be_a(CMDx::Result)
      expect(result.task).to be_a(task_class)
    end

    context "when calling with a Result object" do
      let(:source_task) { task_class.new(user_id: 789, email: "test@example.com") }
      let(:source_result) { source_task.tap(&:perform).result }

      it "extracts context from Result object and executes" do
        result = task_class.call(source_result)

        expect(result).to be_a(CMDx::Result)
        expect(result.context.user_id).to eq(789)
        expect(result.context.email).to eq("test@example.com")
      end

      it "creates new task instance with extracted context" do
        result = task_class.call(source_result)

        expect(result.task).to be_a(task_class)
        expect(result.task).not_to be(source_task)
        expect(result).not_to be(source_result)
      end
    end
  end

  describe ".call!" do
    it "creates a new instance and calls perform!" do
      result = task_class.call!

      expect(result).to be_a(CMDx::Result)
    end

    it "passes arguments to new instance" do
      params = { user_id: 456, email: "test@example.com" }
      result = task_class.call!(params)

      expect(result.context.user_id).to eq(456)
      expect(result.context.email).to eq("test@example.com")
    end

    it "raises exception for failures when task_halt includes status" do
      failing_task = create_failing_task(reason: "Something went wrong")

      expect { failing_task.call! }.to raise_error(CMDx::Failed)
    end

    context "when calling with a Result object" do
      let(:source_task) { task_class.new(user_id: 999, status: "active") }
      let(:source_result) { source_task.tap(&:perform).result }

      it "extracts context from Result object and executes" do
        result = task_class.call!(source_result)

        expect(result).to be_a(CMDx::Result)
        expect(result.context.user_id).to eq(999)
        expect(result.context.status).to eq("active")
      end

      it "creates new task instance with extracted context" do
        result = task_class.call!(source_result)

        expect(result.task).to be_a(task_class)
        expect(result.task).not_to be(source_task)
        expect(result).not_to be(source_result)
      end
    end
  end

  describe ".task_setting" do
    it "returns setting value" do
      task_class.task_settings!(timeout: 30)

      expect(task_class.task_setting(:timeout)).to eq(30)
    end

    it "evaluates callable settings" do
      task_class.task_settings!(current_time: -> { Time.now })

      expect(task_class.task_setting(:current_time)).to be_a(Time)
    end

    it "returns nil for non-existent settings" do
      expect(task_class.task_setting(:non_existent)).to be_nil
    end
  end

  describe ".task_setting?" do
    it "returns true for existing settings" do
      task_class.task_settings!(timeout: 30)

      expect(task_class.task_setting?(:timeout)).to be(true)
    end

    it "returns false for non-existent settings" do
      expect(task_class.task_setting?(:non_existent)).to be(false)
    end
  end

  describe ".task_settings!" do
    it "merges new settings with existing ones" do
      task_class.task_settings!(timeout: 30, retries: 3)

      expect(task_class.task_setting(:timeout)).to eq(30)
      expect(task_class.task_setting(:retries)).to eq(3)
    end

    it "overwrites existing settings" do
      task_class.task_settings!(timeout: 30)
      task_class.task_settings!(timeout: 60)

      expect(task_class.task_setting(:timeout)).to eq(60)
    end

    it "returns updated settings hash" do
      result = task_class.task_settings!(timeout: 30)

      expect(result).to be_a(Hash)
      expect(result[:timeout]).to eq(30)
    end
  end

  describe ".use" do
    let(:middleware_class) do
      create_middleware_class(name: "TestMiddleware") do
        def initialize(options = {})
          @options = options
        end

        def call(task, callable)
          callable.call(task)
        end
      end
    end

    it "adds middleware to registry" do
      task_class.use(middleware_class)

      expect(task_class.cmd_middlewares.registry).not_to be_empty
    end

    it "accepts middleware with arguments" do
      task_class.use(middleware_class, timeout: 30)

      expect(task_class.cmd_middlewares.registry).not_to be_empty
    end

    it "returns middleware registry" do
      result = task_class.use(middleware_class)

      expect(result).to be_a(CMDx::MiddlewareRegistry)
    end
  end

  describe ".optional" do
    # Use a fresh task class for parameter tests to avoid contamination
    let(:parameter_task_class) { create_simple_task(name: "ParameterTask") }

    it "adds optional parameters to registry" do
      parameter_task_class.optional(:timeout, type: :integer, default: 30)

      expect(parameter_task_class.cmd_parameters).not_to be_empty
    end

    it "accepts multiple parameters" do
      parameter_task_class.optional(:timeout, :retries, type: :integer)

      expect(parameter_task_class.cmd_parameters.size).to eq(2)
    end
  end

  describe ".required" do
    # Use a fresh task class for parameter tests to avoid contamination
    let(:parameter_task_class) { create_simple_task(name: "ParameterTask") }

    it "adds required parameters to registry" do
      parameter_task_class.required(:user_id, type: :integer)

      expect(parameter_task_class.cmd_parameters).not_to be_empty
    end

    it "accepts multiple parameters" do
      parameter_task_class.required(:user_id, :email, type: :string)

      expect(parameter_task_class.cmd_parameters.size).to eq(2)
    end
  end

  describe "callback methods" do
    it "defines before_validation callback method" do
      expect(task_class).to respond_to(:before_validation)
    end

    it "defines after_validation callback method" do
      expect(task_class).to respond_to(:after_validation)
    end

    it "defines before_execution callback method" do
      expect(task_class).to respond_to(:before_execution)
    end

    it "defines after_execution callback method" do
      expect(task_class).to respond_to(:after_execution)
    end

    it "defines on_success callback method" do
      expect(task_class).to respond_to(:on_success)
    end

    it "defines on_failed callback method" do
      expect(task_class).to respond_to(:on_failed)
    end

    it "defines on_executed callback method" do
      expect(task_class).to respond_to(:on_executed)
    end

    it "accepts callables and options" do
      expect do
        task_class.before_execution(:setup_method, if: :should_setup?)
      end.not_to raise_error
    end

    it "accepts blocks" do
      expect do
        task_class.on_success { |task| task.context.callback_executed = true }
      end.not_to raise_error
    end
  end

  describe "#initialize" do
    subject(:task) { task_class.new(user_id: 123) }

    it "generates unique id" do
      expect(task.id).to be_a(String)
      expect(task.id).not_to be_empty
    end

    it "initializes errors collection" do
      expect(task.errors).to be_a(CMDx::Errors)
    end

    it "builds context from parameters" do
      expect(task.context).to be_a(CMDx::Context)
      expect(task.context.user_id).to eq(123)
    end

    it "creates result object" do
      expect(task.result).to be_a(CMDx::Result)
      expect(task.result.task).to be(task)
    end

    it "builds execution chain" do
      expect(task.chain).to be_a(CMDx::Chain)
    end

    it "provides context alias as ctx" do
      expect(task.ctx).to be(task.context)
    end

    it "provides result alias as res" do
      expect(task.res).to be(task.result)
    end

    context "when initializing with a Result object" do
      let(:source_task) { task_class.new(user_id: 456, name: "Source Task") }
      let(:source_result) { source_task.tap(&:perform).result }

      it "extracts context from Result object" do
        new_task = task_class.new(source_result)

        expect(new_task.context.user_id).to eq(456)
        expect(new_task.context.name).to eq("Source Task")
      end

      it "creates new Result object for new task" do
        new_task = task_class.new(source_result)

        expect(new_task.result).to be_a(CMDx::Result)
        expect(new_task.result).not_to be(source_result)
        expect(new_task.result.task).to be(new_task)
      end

      it "preserves context data when passed as Result" do
        # Create and execute a task with additional context data
        source_task = task_class.new(user_id: 789, name: "Source Task")
        source_task.context.additional_data = "test value"
        source_task.perform

        new_task = task_class.new(source_task.result)

        expect(new_task.context.additional_data).to eq("test value")
        expect(new_task.context.user_id).to eq(789)
        expect(new_task.context.name).to eq("Source Task")
      end
    end
  end

  describe "#call" do
    subject(:task) { task_class.new }

    it "raises UndefinedCallError when not implemented" do
      undefined_task = create_task_class
      instance = undefined_task.new

      expect { instance.call }.to raise_error(CMDx::UndefinedCallError)
    end

    it "does not raise error when implemented" do
      expect { task.call }.not_to raise_error
    end
  end

  describe "#perform" do
    subject(:task) { task_class.new }

    it "executes the task" do
      task.perform

      expect(task.result.executed?).to be(true)
    end

    it "handles exceptions gracefully" do
      failing_task = create_erroring_task(reason: "Something went wrong")

      instance = failing_task.new
      instance.perform

      expect(instance.result.failed?).to be(true)
    end

    it "freezes task after execution" do
      # Temporarily disable freezing skip to test freezing behavior
      original_env = ENV.fetch("SKIP_CMDX_FREEZING", nil)
      ENV.delete("SKIP_CMDX_FREEZING")

      task.perform

      expect(task).to be_frozen

      # Restore original environment
      ENV["SKIP_CMDX_FREEZING"] = original_env if original_env
    end

    it "calls middleware when present" do
      middleware_called = false
      middleware_class = create_middleware_class(name: "TrackingMiddleware") do
        define_method(:call) do |task, next_callable|
          middleware_called = true
          next_callable.call(task)
        end
      end

      task_class.use(middleware_class.new)
      task.perform

      expect(middleware_called).to be(true)
    end
  end

  describe "#perform!" do
    subject(:task) { task_class.new }

    it "executes the task" do
      task.perform!

      expect(task.result.executed?).to be(true)
    end

    it "raises exceptions for failures" do
      failing_task = create_failing_task(reason: "Something went wrong")

      instance = failing_task.new

      expect { instance.perform! }.to raise_error(CMDx::Failed)
    end

    it "calls middleware when present" do
      middleware_called = false
      middleware_class = create_middleware_class(name: "TrackingMiddleware") do
        define_method(:call) do |task, next_callable|
          middleware_called = true
          next_callable.call(task)
        end
      end

      task_class.use(middleware_class.new)
      task.perform!

      expect(middleware_called).to be(true)
    end
  end

  describe "delegation methods" do
    subject(:task) { task_class.new }

    it "delegates skip! to result" do
      expect(task.result).to receive(:skip!)
      task.skip!
    end

    it "delegates fail! to result" do
      expect(task.result).to receive(:fail!)
      task.fail!
    end

    it "delegates throw! to result" do
      expect(task.result).to receive(:throw!)
      task.throw!
    end

    it "delegates cmd_middlewares to class" do
      expect(task.cmd_middlewares).to be(task_class.cmd_middlewares)
    end

    it "delegates cmd_callbacks to class" do
      expect(task.cmd_callbacks).to be(task_class.cmd_callbacks)
    end

    it "delegates cmd_parameters to class" do
      expect(task.cmd_parameters).to be(task_class.cmd_parameters)
    end

    it "delegates task_setting to class" do
      task_class.task_settings!(timeout: 30)

      expect(task.task_setting(:timeout)).to eq(30)
    end

    it "delegates task_setting? to class" do
      task_class.task_settings!(timeout: 30)

      expect(task.task_setting?(:timeout)).to be(true)
    end
  end

  describe "parameter handling" do
    let(:parameterized_task) do
      create_task_class(name: "ParameterizedTask") do
        required :user_id, type: :integer
        optional :notify, type: :boolean, default: true

        def call
          context.result = "User #{user_id} processed"
          context.notify = notify # Access the parameter to trigger default resolution
        end
      end
    end

    it "validates required parameters" do
      result = parameterized_task.call

      expect(result.failed?).to be(true)
      expect(result.metadata[:reason]).to include("is a required parameter")
    end

    it "allows access to parameters in call method" do
      result = parameterized_task.call(user_id: 123)

      expect(result.context.result).to eq("User 123 processed")
    end

    it "applies default values for optional parameters" do
      result = parameterized_task.call(user_id: 123)

      expect(result.context.notify).to be(true)
    end

    it "accepts explicit values for optional parameters" do
      result = parameterized_task.call(user_id: 123, notify: false)

      expect(result.context.notify).to be(false)
    end
  end

  describe "callback execution" do
    let(:callback_tracking) { [] }
    let(:callbacked_task) do
      tracking = callback_tracking
      create_task_class(name: "CallbackedTask") do
        before_execution -> { tracking << :before_execution }
        after_execution -> { tracking << :after_execution }
        on_success -> { tracking << :on_success }

        def call
          # Successful execution
        end
      end
    end

    it "executes callbacks in correct order" do
      callbacked_task.call

      expect(callback_tracking).to include(:before_execution, :after_execution, :on_success)
    end

    it "executes before_execution callbacks before call" do
      callbacked_task.call

      expect(callback_tracking.first).to eq(:before_execution)
    end

    it "executes after_execution callbacks after call" do
      callbacked_task.call

      expect(callback_tracking.last).to eq(:after_execution)
    end
  end

  describe "error handling" do
    let(:error_task) do
      create_erroring_task(reason: "Test error")
    end

    it "captures exceptions in perform" do
      instance = error_task.new
      instance.perform

      expect(instance.result.failed?).to be(true)
      expect(instance.result.metadata[:reason]).to eq("[StandardError] Test error")
      expect(instance.result.metadata[:original_exception]).to be_a(StandardError)
    end

    it "propagates exceptions in perform!" do
      instance = error_task.new

      expect { instance.perform! }.to raise_error(StandardError)
    end
  end

  describe "result state management" do
    let(:state_task) do
      create_task_class(name: "StateTask") do
        def call
          context.processed = true
        end
      end
    end

    it "starts with initialized state" do
      instance = state_task.new

      expect(instance.result.initialized?).to be(true)
    end

    it "transitions to executing during call" do
      task_with_callback = create_task_class(name: "TaskWithCallback") do
        on_executing do
          context.executing_captured = result.executing?
        end

        def call
          # Implementation
        end
      end

      result = task_with_callback.call

      expect(result.context.executing_captured).to be(true)
    end

    it "transitions to executed after call" do
      result = state_task.call

      expect(result.executed?).to be(true)
    end

    it "sets success status for completed tasks" do
      result = state_task.call

      expect(result.success?).to be(true)
    end
  end
end

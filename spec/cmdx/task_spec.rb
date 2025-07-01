# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  let(:task_class) do
    Class.new(described_class) do
      def call
        # Basic implementation for testing
      end
    end
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
      failing_task = Class.new(described_class) do
        def call
          fail!(reason: "Something went wrong")
        end
      end

      expect { failing_task.call! }.to raise_error(CMDx::Failed)
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
      Class.new do
        def initialize(options = {})
          @options = options
        end

        def call(task, &)
          yield(task)
        end
      end
    end

    it "adds middleware to registry" do
      task_class.use(middleware_class)

      expect(task_class.cmd_middlewares).not_to be_empty
    end

    it "accepts middleware with arguments" do
      task_class.use(middleware_class, timeout: 30)

      expect(task_class.cmd_middlewares).not_to be_empty
    end

    it "returns middleware registry" do
      result = task_class.use(middleware_class)

      expect(result).to be_a(CMDx::MiddlewareRegistry)
    end
  end

  describe ".register" do
    it "adds hook to registry" do
      task_class.register(:before_execution, :setup_method)

      expect(task_class.cmd_hooks[:before_execution]).not_to be_empty
    end

    it "accepts hook with conditions" do
      task_class.register(:on_success, :notify_users, if: :should_notify?)

      expect(task_class.cmd_hooks[:on_success]).not_to be_empty
    end

    it "returns hook registry" do
      result = task_class.register(:after_execution, :cleanup_method)

      expect(result).to be_a(CMDx::HookRegistry)
    end
  end

  describe ".optional" do
    it "adds optional parameters to registry" do
      task_class.optional(:timeout, type: :integer, default: 30)

      expect(task_class.cmd_parameters).not_to be_empty
    end

    it "accepts multiple parameters" do
      task_class.optional(:timeout, :retries, type: :integer)

      expect(task_class.cmd_parameters.size).to eq(2)
    end

    it "returns parameter registry" do
      result = task_class.optional(:timeout, type: :integer)

      expect(result).to be_a(CMDx::ParameterRegistry)
    end
  end

  describe ".required" do
    it "adds required parameters to registry" do
      task_class.required(:user_id, type: :integer)

      expect(task_class.cmd_parameters).not_to be_empty
    end

    it "accepts multiple parameters" do
      task_class.required(:user_id, :email, type: :string)

      expect(task_class.cmd_parameters.size).to eq(2)
    end

    it "returns parameter registry" do
      result = task_class.required(:user_id, type: :integer)

      expect(result).to be_a(CMDx::ParameterRegistry)
    end
  end

  describe "hook methods" do
    it "defines before_validation hook method" do
      expect(task_class).to respond_to(:before_validation)
    end

    it "defines after_validation hook method" do
      expect(task_class).to respond_to(:after_validation)
    end

    it "defines before_execution hook method" do
      expect(task_class).to respond_to(:before_execution)
    end

    it "defines after_execution hook method" do
      expect(task_class).to respond_to(:after_execution)
    end

    it "defines on_success hook method" do
      expect(task_class).to respond_to(:on_success)
    end

    it "defines on_failed hook method" do
      expect(task_class).to respond_to(:on_failed)
    end

    it "defines on_executed hook method" do
      expect(task_class).to respond_to(:on_executed)
    end

    it "accepts callables and options" do
      expect do
        task_class.before_execution(:setup_method, if: :should_setup?)
      end.not_to raise_error
    end

    it "accepts blocks" do
      expect do
        task_class.on_success { |_task| puts "Success!" }
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
  end

  describe "#call" do
    subject(:task) { task_class.new }

    it "raises UndefinedCallError when not implemented" do
      undefined_task = Class.new(described_class)
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
      failing_task = Class.new(described_class) do
        def call
          raise StandardError, "Something went wrong"
        end
      end

      instance = failing_task.new
      instance.perform

      expect(instance.result.failed?).to be(true)
    end

    it "freezes task after execution" do
      # Temporarily disable test environment detection to test freezing behavior
      original_rails_env = ENV.fetch("RAILS_ENV", nil)
      original_rack_env = ENV.fetch("RACK_ENV", nil)
      ENV.delete("RAILS_ENV")
      ENV.delete("RACK_ENV")

      task.perform

      expect(task).to be_frozen

      # Restore original environment
      ENV["RAILS_ENV"] = original_rails_env if original_rails_env
      ENV["RACK_ENV"] = original_rack_env if original_rack_env
    end

    it "calls middleware when present" do
      middleware_called = false
      middleware = Class.new do
        define_method(:call) do |task, next_callable|
          middleware_called = true
          next_callable.call(task)
        end
      end

      task_class.use(middleware.new)
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
      failing_task = Class.new(described_class) do
        def call
          fail!(reason: "Something went wrong")
        end
      end

      instance = failing_task.new

      expect { instance.perform! }.to raise_error(CMDx::Failed)
    end

    it "calls middleware when present" do
      middleware_called = false
      middleware = Class.new do
        define_method(:call) do |task, next_callable|
          middleware_called = true
          next_callable.call(task)
        end
      end

      task_class.use(middleware.new)
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

    it "delegates cmd_hooks to class" do
      expect(task.cmd_hooks).to be(task_class.cmd_hooks)
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
      Class.new(described_class) do
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

  describe "hook execution" do
    let(:hook_tracking) { [] }
    let(:hooked_task) do
      tracking = hook_tracking
      Class.new(described_class) do
        before_execution -> { tracking << :before_execution }
        after_execution -> { tracking << :after_execution }
        on_success -> { tracking << :on_success }

        def call
          # Successful execution
        end
      end
    end

    it "executes hooks in correct order" do
      hooked_task.call

      expect(hook_tracking).to include(:before_execution, :after_execution, :on_success)
    end

    it "executes before_execution hooks before call" do
      hooked_task.call

      expect(hook_tracking.first).to eq(:before_execution)
    end

    it "executes after_execution hooks after call" do
      hooked_task.call

      expect(hook_tracking.last).to eq(:after_execution)
    end
  end

  describe "error handling" do
    let(:error_task) do
      Class.new(described_class) do
        def call
          raise StandardError, "Test error"
        end
      end
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
      Class.new(described_class) do
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
      task_with_hook = Class.new(described_class) do
        on_executing do
          context.executing_captured = result.executing?
        end

        def call
          # Implementation
        end
      end

      result = task_with_hook.call

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

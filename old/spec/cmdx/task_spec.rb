# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  subject(:task) { task_class.new(context_data) }

  let(:task_class) { create_simple_task(name: "TestTask") }
  let(:context_data) { { user_id: 123, action: "test" } }

  describe ".new" do
    it "creates task with hash context" do
      expect(task.context.user_id).to eq(123)
      expect(task.context.action).to eq("test")
    end

    it "creates task with existing context" do
      existing_context = CMDx::Context.build(name: "John")
      task = task_class.new(existing_context)

      expect(task.context.name).to eq("John")
    end

    it "creates task with object having context method" do
      context_wrapper = double(context: { name: "Jane" })
      task = task_class.new(context_wrapper)

      expect(task.context.name).to eq("Jane")
    end

    it "initializes context as Context object" do
      expect(task.context).to be_a(CMDx::Context)
    end

    it "initializes errors as Errors object" do
      expect(task.errors).to be_a(CMDx::Errors)
    end

    it "generates unique ID" do
      task1 = task_class.new
      task2 = task_class.new

      expect(task1.id).to be_a(String)
      expect(task2.id).to be_a(String)
      expect(task1.id).not_to eq(task2.id)
    end

    it "initializes result as Result object" do
      expect(task.result).to be_a(CMDx::Result)
      expect(task.result.task).to eq(task)
    end

    it "initializes chain as Chain object" do
      expect(task.chain).to be_a(CMDx::Chain)
      expect(task.chain.results).to include(task.result)
    end
  end

  describe "attribute aliases" do
    it "provides ctx alias for context" do
      expect(task.ctx).to eq(task.context)
    end

    it "provides res alias for result" do
      expect(task.res).to eq(task.result)
    end
  end

  describe "delegation to result" do
    it "delegates skip! to result" do
      expect(task.result).to receive(:skip!).with(reason: "test")
      task.skip!(reason: "test")
    end

    it "delegates fail! to result" do
      expect(task.result).to receive(:fail!).with(reason: "error")
      task.fail!(reason: "error")
    end

    it "delegates throw! to result" do
      expect(task.result).to receive(:throw!).with("custom_error")
      task.throw!("custom_error")
    end
  end

  describe "delegation to class" do
    it "delegates cmd_middlewares to class" do
      expect(task.cmd_middlewares).to eq(task_class.cmd_middlewares)
    end

    it "delegates cmd_callbacks to class" do
      expect(task.cmd_callbacks).to eq(task_class.cmd_callbacks)
    end

    it "delegates cmd_parameters to class" do
      expect(task.cmd_parameters).to eq(task_class.cmd_parameters)
    end

    it "delegates cmd_settings to class" do
      expect(task.cmd_settings).to eq(task_class.cmd_settings)
    end

    it "delegates cmd_setting to class" do
      expect(task.cmd_setting(:logger)).to eq(task_class.cmd_setting(:logger))
    end

    it "delegates cmd_setting? to class" do
      expect(task.cmd_setting?(:logger)).to eq(task_class.cmd_setting?(:logger))
    end
  end

  describe "#call" do
    let(:task_class) { Class.new(described_class) }

    it "raises UndefinedCallError when not implemented" do
      task = task_class.new

      expect { task.call }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end
  end

  describe "#process" do
    it "executes task through middleware" do
      expect(task.cmd_middlewares).to receive(:call).with(task).and_yield(task)
      expect(CMDx::TaskProcessor).to receive(:call).with(task)

      task.process
    end
  end

  describe "#process!" do
    it "executes task through middleware with strict handling" do
      expect(task.cmd_middlewares).to receive(:call).with(task).and_yield(task)
      expect(CMDx::TaskProcessor).to receive(:call!).with(task)

      task.process!
    end
  end

  describe "#logger" do
    it "creates logger for the task" do
      expect(CMDx::Logger).to receive(:call).with(task)

      task.send(:logger)
    end
  end

  describe "class methods" do
    describe "callback registration" do
      CMDx::CallbackRegistry::TYPES.each do |callback_type|
        describe ".#{callback_type}" do
          it "registers callback with symbol" do
            expect(task_class.cmd_callbacks).to receive(:register) do |type, *callables, **options|
              expect(type).to eq(callback_type)
              expect(callables).to eq([:test_callback])
              expect(options).to eq({})
            end

            task_class.public_send(callback_type, :test_callback)
          end

          it "registers callback with proc" do
            proc_callback = -> { puts "test" }
            expect(task_class.cmd_callbacks).to receive(:register) do |type, *callables, **options|
              expect(type).to eq(callback_type)
              expect(callables).to eq([proc_callback])
              expect(options).to eq({})
            end

            task_class.public_send(callback_type, proc_callback)
          end

          it "registers callback with options" do
            expect(task_class.cmd_callbacks).to receive(:register) do |type, *callables, **options|
              expect(type).to eq(callback_type)
              expect(callables).to eq([:test_callback])
              expect(options).to eq({ if: :condition })
            end

            task_class.public_send(callback_type, :test_callback, if: :condition)
          end

          it "registers callback with block" do
            expect(task_class.cmd_callbacks).to receive(:register) do |type, *callables, **options, &block|
              expect(type).to eq(callback_type)
              expect(callables).to eq([])
              expect(options).to eq({})
              expect(block).to be_a(Proc)
            end

            task_class.public_send(callback_type) { puts "test" }
          end

          it "registers multiple callbacks" do
            expect(task_class.cmd_callbacks).to receive(:register) do |type, *callables, **options|
              expect(type).to eq(callback_type)
              expect(callables).to eq(%i[first second])
              expect(options).to eq({})
            end

            task_class.public_send(callback_type, :first, :second)
          end
        end
      end
    end

    describe ".cmd_setting" do
      it "returns setting value" do
        task_class.cmd_settings!(test_setting: "test_value")

        expect(task_class.cmd_setting(:test_setting)).to eq("test_value")
      end

      it "processes setting through cmdx_yield" do
        callable_setting = -> { "dynamic_value" }
        task_class.cmd_settings!(test_setting: callable_setting)

        expect(task_class.cmd_setting(:test_setting)).to eq("dynamic_value")
      end
    end

    describe ".cmd_setting?" do
      it "returns true for existing setting" do
        task_class.cmd_settings!(existing_setting: "value")

        expect(task_class.cmd_setting?(:existing_setting)).to be(true)
      end

      it "returns false for non-existing setting" do
        expect(task_class.cmd_setting?(:non_existing)).to be(false)
      end
    end

    describe ".cmd_settings!" do
      it "merges new settings" do
        original_logger = task_class.cmd_setting(:logger)
        task_class.cmd_settings!(task_halt: "custom", new_setting: "value")

        expect(task_class.cmd_setting(:task_halt)).to eq("custom")
        expect(task_class.cmd_setting(:new_setting)).to eq("value")
        expect(task_class.cmd_setting(:logger)).to eq(original_logger)
      end

      it "returns updated settings hash" do
        result = task_class.cmd_settings!(test: "value")

        expect(result).to include(test: "value")
      end
    end

    describe ".use" do
      context "with middleware type" do
        let(:middleware) { double("middleware") }

        it "registers middleware" do
          expect(task_class.cmd_middlewares).to receive(:register).with(middleware, timeout: 30)

          task_class.use(:middleware, middleware, timeout: 30)
        end
      end

      context "with callback type" do
        it "registers callback" do
          expect(task_class.cmd_callbacks).to receive(:register).with(:callback, :before_execution, :test_callback)

          task_class.use(:callback, :before_execution, :test_callback)
        end
      end

      context "with validator type" do
        it "registers validator" do
          expect(task_class).to receive(:cmd_validators).and_return(double(register: nil))

          task_class.use(:validator, :presence, :field)
        end
      end

      context "with coercion type" do
        it "registers coercion" do
          expect(task_class).to receive(:cmd_coercions).and_return(double(register: nil))

          task_class.use(:coercion, :string, :field)
        end
      end
    end

    describe ".optional" do
      it "creates optional parameters" do
        expect(CMDx::Parameter).to receive(:optional).with(:name, :email, type: :string, klass: task_class).and_return([])

        task_class.optional :name, :email, type: :string
      end

      it "adds parameters to registry" do
        parameters = [double("parameter")]
        allow(CMDx::Parameter).to receive(:optional).and_return(parameters)

        expect(task_class.cmd_parameters.registry).to receive(:concat).with(parameters)

        task_class.optional :name
      end

      it "passes block to Parameter.optional" do
        block = proc { puts "test" }
        expect(CMDx::Parameter).to receive(:optional).with(:user, type: :hash, klass: task_class) do |&passed_block|
          expect(passed_block).to eq(block)
        end.and_return([])

        task_class.optional :user, type: :hash, &block
      end
    end

    describe ".required" do
      it "creates required parameters" do
        expect(CMDx::Parameter).to receive(:required).with(:user_id, :action, type: :string, klass: task_class).and_return([])

        task_class.required :user_id, :action, type: :string
      end

      it "adds parameters to registry" do
        parameters = [double("parameter")]
        allow(CMDx::Parameter).to receive(:required).and_return(parameters)

        expect(task_class.cmd_parameters.registry).to receive(:concat).with(parameters)

        task_class.required :user_id
      end

      it "passes block to Parameter.required" do
        block = proc { puts "test" }
        expect(CMDx::Parameter).to receive(:required).with(:user, type: :hash, klass: task_class) do |&passed_block|
          expect(passed_block).to eq(block)
        end.and_return([])

        task_class.required :user, type: :hash, &block
      end
    end

    describe ".call" do
      it "creates instance and processes it" do
        allow(task_class).to receive(:new).with(user_id: 123).and_call_original
        expect_any_instance_of(task_class).to receive(:process)

        result = task_class.call(user_id: 123)

        expect(result).to be_a(CMDx::Result)
      end

      it "returns result from executed task" do
        result = task_class.call(user_id: 123)

        expect(result.context.user_id).to eq(123)
        expect(result.context.executed).to be(true)
      end
    end

    describe ".call!" do
      it "creates instance and processes it with strict handling" do
        allow(task_class).to receive(:new).with(user_id: 123).and_call_original
        expect_any_instance_of(task_class).to receive(:process!)

        result = task_class.call!(user_id: 123)

        expect(result).to be_a(CMDx::Result)
      end

      it "returns result from executed task" do
        result = task_class.call!(user_id: 123)

        expect(result.context.user_id).to eq(123)
        expect(result.context.executed).to be(true)
      end

      context "when task fails with halt setting" do
        let(:failing_task_class) do
          create_failing_task(name: "FailingTask").tap do |klass|
            klass.cmd_settings!(task_halt: ["failed"])
          end
        end

        it "raises Fault for failed task with halt setting" do
          expect { failing_task_class.call! }.to raise_error(CMDx::Fault)
        end
      end
    end
  end

  describe "settings defaults" do
    it "has default cmd_settings" do
      expect(task_class.cmd_settings).to include(:logger, :task_halt, :workflow_halt, :tags)
      expect(task_class.cmd_settings[:tags]).to eq([])
    end

    it "has default cmd_middlewares" do
      expect(task_class.cmd_middlewares).to be_a(CMDx::MiddlewareRegistry)
    end

    it "has default cmd_callbacks" do
      expect(task_class.cmd_callbacks).to be_a(CMDx::CallbackRegistry)
    end

    it "has default cmd_parameters" do
      expect(task_class.cmd_parameters).to be_a(CMDx::ParameterRegistry)
    end
  end

  describe "integration scenarios" do
    let(:integrated_task_class) do
      create_task_class(name: "IntegratedTask") do
        required :user_id, type: :integer
        optional :message, type: :string, default: "Hello"

        before_execution :setup
        on_success :cleanup

        def call
          context.processed_user = user_id * 2
          context.final_message = message
        end

        private

        def setup
          context.setup_done = true
        end

        def cleanup
          context.cleanup_done = true
        end
      end
    end

    it "executes full task lifecycle" do
      result = integrated_task_class.call(user_id: 5, message: "Hello")

      expect(result).to be_successful_task
      expect(result.context.user_id).to eq(5)
      expect(result.context.message).to eq("Hello")
      expect(result.context.processed_user).to eq(10)
      expect(result.context.final_message).to eq("Hello")
      expect(result.context.setup_done).to be(true)
      expect(result.context.cleanup_done).to be(true)
    end

    it "validates required parameters" do
      result = integrated_task_class.call(message: "Custom")

      expect(result).to be_failed_task
      expect(result.metadata[:reason]).to include("user_id")
    end

    it "coerces parameter types" do
      result = integrated_task_class.call(user_id: "10")

      expect(result).to be_successful_task
      expect(result.context.user_id).to eq("10")
      expect(result.context.processed_user).to eq(20)
    end
  end

  describe "error handling" do
    context "when task raises exception" do
      let(:erroring_task_class) { create_erroring_task(name: "ErroringTask", reason: "Database error") }

      it "handles exception in process" do
        task = erroring_task_class.new
        task.process

        expect(task.result).to be_failed_task
        expect(task.result.metadata[:reason]).to include("Database error")
      end

      it "propagates exception in process!" do
        task = erroring_task_class.new

        expect { task.process! }.to raise_error(StandardError, "Database error")
      end
    end

    context "when task uses fail!" do
      let(:failing_task_class) { create_failing_task(name: "FailingTask", reason: "Validation failed") }

      it "marks result as failed" do
        result = failing_task_class.call

        expect(result).to be_failed_task
        expect(result.metadata[:reason]).to eq("Validation failed")
      end
    end

    context "when task uses skip!" do
      let(:skipping_task_class) { create_skipping_task(name: "SkippingTask", reason: "Feature disabled") }

      it "marks result as skipped" do
        result = skipping_task_class.call

        expect(result).to be_skipped_task
        expect(result.metadata[:reason]).to eq("Feature disabled")
      end
    end
  end
end

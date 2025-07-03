# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Callback do
  describe "#call" do
    let(:callback) { described_class.new }
    let(:task) { mock_task }
    let(:callback_type) { :before_validation }

    it "raises UndefinedCallError when not implemented" do
      expect { callback.call(task, callback_type) }.to raise_error(
        CMDx::UndefinedCallError,
        "call method not defined in CMDx::Callback"
      )
    end

    it "includes the actual class name in error message" do
      custom_callback_class = Class.new(described_class)
      custom_callback = custom_callback_class.new

      expect { custom_callback.call(task, callback_type) }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end

    it "accepts task and callback_type parameters" do
      expect { callback.call(task, callback_type) }.to raise_error(CMDx::UndefinedCallError)
    end

    it "accepts any number of parameters without error when overridden" do
      callback_class = Class.new(described_class) do
        def call(*args)
          args
        end
      end
      callback_instance = callback_class.new

      expect(callback_instance.call(task, callback_type)).to eq([task, callback_type])
    end
  end

  describe "subclass implementation" do
    let(:task) { mock_task(class: double(name: "TestTask")) }
    let(:callback_type) { :on_success }

    context "when subclass implements call method" do
      let(:callback_class) do
        Class.new(described_class) do
          def call(task, callback_type)
            "Callback executed for #{task.class.name} with #{callback_type}"
          end
        end
      end
      let(:callback) { callback_class.new }

      it "executes the overridden call method" do
        result = callback.call(task, callback_type)

        expect(result).to eq("Callback executed for TestTask with on_success")
      end

      it "can access task parameter" do
        callback_class = Class.new(described_class) do
          def call(task, _callback_type)
            task.class.name
          end
        end
        callback = callback_class.new

        expect(callback.call(task, callback_type)).to eq("TestTask")
      end

      it "can access callback_type parameter" do
        callback_class = Class.new(described_class) do
          def call(_task, callback_type)
            callback_type
          end
        end
        callback = callback_class.new

        expect(callback.call(task, callback_type)).to eq(:on_success)
      end
    end

    context "when subclass has initialization parameters" do
      let(:callback_class) do
        Class.new(described_class) do
          def initialize(prefix)
            @prefix = prefix
          end

          def call(_task, callback_type)
            "#{@prefix}: #{callback_type}"
          end
        end
      end

      it "can use initialization parameters in call method" do
        callback = callback_class.new("LOG")

        expect(callback.call(task, callback_type)).to eq("LOG: on_success")
      end
    end

    context "when subclass performs conditional logic" do
      let(:callback_class) do
        Class.new(described_class) do
          def call(_task, callback_type)
            return "skipped" unless callback_type == :on_success

            "executed"
          end
        end
      end
      let(:callback) { callback_class.new }

      it "executes when condition is met" do
        expect(callback.call(task, :on_success)).to eq("executed")
      end

      it "skips when condition is not met" do
        expect(callback.call(task, :on_failure)).to eq("skipped")
      end
    end

    context "when subclass interacts with task state" do
      let(:callback_class) do
        Class.new(described_class) do
          def call(task, _callback_type)
            task.result.status if task.respond_to?(:result)
          end
        end
      end
      let(:callback) { callback_class.new }
      let(:result) { mock_result(status: "completed") }
      let(:task_with_result) { mock_task(result: result) }

      it "can interact with task properties" do
        expect(callback.call(task_with_result, callback_type)).to eq("completed")
      end

      it "handles tasks without expected properties" do
        task_without_result = double("Task")
        allow(task_without_result).to receive(:respond_to?).with(:result).and_return(false)
        expect(callback.call(task_without_result, callback_type)).to be_nil
      end
    end

    context "when subclass raises errors" do
      let(:callback_class) do
        Class.new(described_class) do
          def call(_task, _callback_type)
            raise StandardError, "Callback execution failed"
          end
        end
      end
      let(:callback) { callback_class.new }

      it "propagates errors from callback execution" do
        expect { callback.call(task, callback_type) }.to raise_error(
          StandardError,
          "Callback execution failed"
        )
      end
    end

    context "when subclass returns different types" do
      it "can return nil" do
        callback_class = Class.new(described_class) do
          def call(_task, _callback_type)
            nil
          end
        end
        callback = callback_class.new

        expect(callback.call(task, callback_type)).to be_nil
      end

      it "can return boolean values" do
        callback_class = Class.new(described_class) do
          def call(_task, callback_type)
            callback_type == :on_success
          end
        end
        callback = callback_class.new

        expect(callback.call(task, :on_success)).to be(true)
        expect(callback.call(task, :on_failure)).to be(false)
      end

      it "can return complex objects" do
        callback_class = Class.new(described_class) do
          def call(task, callback_type)
            { task: task.class.name, callback: callback_type, timestamp: Time.now }
          end
        end
        callback = callback_class.new

        result = callback.call(task, callback_type)
        expect(result).to include(task: "TestTask", callback: :on_success)
        expect(result[:timestamp]).to be_a(Time)
      end
    end
  end

  describe "inheritance" do
    it "can be subclassed" do
      callback_class = Class.new(described_class)

      expect(callback_class.superclass).to eq(described_class)
      expect(callback_class.new).to be_a(described_class)
    end

    it "supports multiple levels of inheritance" do
      base_callback = Class.new(described_class) do
        def call(_task, _callback_type)
          "base"
        end
      end

      specialized_callback = Class.new(base_callback) do
        def call(task, callback_type)
          "#{super} specialized"
        end
      end

      callback = specialized_callback.new
      expect(callback.call(mock_task, :test)).to eq("base specialized")
    end

    it "allows callbacks to share common functionality" do
      logging_callback = Class.new(described_class) do
        def call(task, callback_type)
          log_message(task, callback_type)
        end

        private

        def log_message(task, callback_type)
          "Logged: #{task.class.name} - #{callback_type}"
        end
      end

      callback = logging_callback.new
      task = mock_task(class: double(name: "MyTask"))

      expect(callback.call(task, :test)).to eq("Logged: MyTask - test")
    end
  end

  describe "method signature flexibility" do
    it "allows callbacks with additional parameters" do
      callback_class = Class.new(described_class) do
        def call(task, callback_type, *additional_args, **kwargs)
          [task, callback_type, additional_args, kwargs]
        end
      end
      callback = callback_class.new

      result = callback.call(mock_task, :test, "extra", key: "value")
      expect(result[2]).to eq(["extra"])
      expect(result[3]).to eq(key: "value")
    end

    it "allows callbacks with block parameters" do
      callback_class = Class.new(described_class) do
        def call(_task, _callback_type, &block)
          block&.call || "no block"
        end
      end
      callback = callback_class.new

      result_with_block = callback.call(mock_task, :test) { "block executed" }
      result_without_block = callback.call(mock_task, :test)

      expect(result_with_block).to eq("block executed")
      expect(result_without_block).to eq("no block")
    end
  end
end

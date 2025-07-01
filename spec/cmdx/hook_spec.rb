# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Hook do
  describe "#call" do
    let(:hook) { described_class.new }
    let(:task) { double("Task") }
    let(:hook_type) { :before_validation }

    it "raises UndefinedCallError when not implemented" do
      expect { hook.call(task, hook_type) }.to raise_error(
        CMDx::UndefinedCallError,
        "call method not defined in CMDx::Hook"
      )
    end

    it "includes the actual class name in error message" do
      custom_hook_class = Class.new(described_class)
      custom_hook = custom_hook_class.new

      expect { custom_hook.call(task, hook_type) }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end

    it "accepts task and hook_type parameters" do
      expect { hook.call(task, hook_type) }.to raise_error(CMDx::UndefinedCallError)
    end

    it "accepts any number of parameters without error when overridden" do
      hook_class = Class.new(described_class) do
        def call(*args)
          args
        end
      end
      hook_instance = hook_class.new

      expect(hook_instance.call(task, hook_type)).to eq([task, hook_type])
    end
  end

  describe "subclass implementation" do
    let(:task) { double("Task", class: double(name: "TestTask")) }
    let(:hook_type) { :on_success }

    context "when subclass implements call method" do
      let(:hook_class) do
        Class.new(described_class) do
          def call(task, hook_type)
            "Hook executed for #{task.class.name} with #{hook_type}"
          end
        end
      end
      let(:hook) { hook_class.new }

      it "executes the overridden call method" do
        result = hook.call(task, hook_type)

        expect(result).to eq("Hook executed for TestTask with on_success")
      end

      it "can access task parameter" do
        hook_class = Class.new(described_class) do
          def call(task, _hook_type)
            task.class.name
          end
        end
        hook = hook_class.new

        expect(hook.call(task, hook_type)).to eq("TestTask")
      end

      it "can access hook_type parameter" do
        hook_class = Class.new(described_class) do
          def call(_task, hook_type)
            hook_type
          end
        end
        hook = hook_class.new

        expect(hook.call(task, hook_type)).to eq(:on_success)
      end
    end

    context "when subclass has initialization parameters" do
      let(:hook_class) do
        Class.new(described_class) do
          def initialize(prefix)
            @prefix = prefix
          end

          def call(_task, hook_type)
            "#{@prefix}: #{hook_type}"
          end
        end
      end

      it "can use initialization parameters in call method" do
        hook = hook_class.new("LOG")

        expect(hook.call(task, hook_type)).to eq("LOG: on_success")
      end
    end

    context "when subclass performs conditional logic" do
      let(:hook_class) do
        Class.new(described_class) do
          def call(_task, hook_type)
            return "skipped" unless hook_type == :on_success

            "executed"
          end
        end
      end
      let(:hook) { hook_class.new }

      it "executes when condition is met" do
        expect(hook.call(task, :on_success)).to eq("executed")
      end

      it "skips when condition is not met" do
        expect(hook.call(task, :on_failure)).to eq("skipped")
      end
    end

    context "when subclass interacts with task state" do
      let(:hook_class) do
        Class.new(described_class) do
          def call(task, _hook_type)
            task.result.status if task.respond_to?(:result)
          end
        end
      end
      let(:hook) { hook_class.new }
      let(:result) { double("Result", status: "completed") }
      let(:task_with_result) { double("Task", result: result) }

      it "can interact with task properties" do
        expect(hook.call(task_with_result, hook_type)).to eq("completed")
      end

      it "handles tasks without expected properties" do
        expect(hook.call(task, hook_type)).to be_nil
      end
    end

    context "when subclass raises errors" do
      let(:hook_class) do
        Class.new(described_class) do
          def call(_task, _hook_type)
            raise StandardError, "Hook execution failed"
          end
        end
      end
      let(:hook) { hook_class.new }

      it "propagates errors from hook execution" do
        expect { hook.call(task, hook_type) }.to raise_error(
          StandardError,
          "Hook execution failed"
        )
      end
    end

    context "when subclass returns different types" do
      it "can return nil" do
        hook_class = Class.new(described_class) do
          def call(_task, _hook_type)
            nil
          end
        end
        hook = hook_class.new

        expect(hook.call(task, hook_type)).to be_nil
      end

      it "can return boolean values" do
        hook_class = Class.new(described_class) do
          def call(_task, hook_type)
            hook_type == :on_success
          end
        end
        hook = hook_class.new

        expect(hook.call(task, :on_success)).to be(true)
        expect(hook.call(task, :on_failure)).to be(false)
      end

      it "can return complex objects" do
        hook_class = Class.new(described_class) do
          def call(task, hook_type)
            { task: task.class.name, hook: hook_type, timestamp: Time.now }
          end
        end
        hook = hook_class.new

        result = hook.call(task, hook_type)
        expect(result).to include(task: "TestTask", hook: :on_success)
        expect(result[:timestamp]).to be_a(Time)
      end
    end
  end

  describe "inheritance" do
    it "can be subclassed" do
      hook_class = Class.new(described_class)

      expect(hook_class.superclass).to eq(described_class)
      expect(hook_class.new).to be_a(described_class)
    end

    it "supports multiple levels of inheritance" do
      base_hook = Class.new(described_class) do
        def call(_task, _hook_type)
          "base"
        end
      end

      specialized_hook = Class.new(base_hook) do
        def call(task, hook_type)
          "#{super} specialized"
        end
      end

      hook = specialized_hook.new
      expect(hook.call(double("Task"), :test)).to eq("base specialized")
    end

    it "allows hooks to share common functionality" do
      logging_hook = Class.new(described_class) do
        def call(task, hook_type)
          log_message(task, hook_type)
        end

        private

        def log_message(task, hook_type)
          "Logged: #{task.class.name} - #{hook_type}"
        end
      end

      hook = logging_hook.new
      task = double("Task", class: double(name: "MyTask"))

      expect(hook.call(task, :test)).to eq("Logged: MyTask - test")
    end
  end

  describe "method signature flexibility" do
    it "allows hooks with additional parameters" do
      hook_class = Class.new(described_class) do
        def call(task, hook_type, *additional_args, **kwargs)
          [task, hook_type, additional_args, kwargs]
        end
      end
      hook = hook_class.new

      result = hook.call(double("Task"), :test, "extra", key: "value")
      expect(result[2]).to eq(["extra"])
      expect(result[3]).to eq(key: "value")
    end

    it "allows hooks with block parameters" do
      hook_class = Class.new(described_class) do
        def call(_task, _hook_type, &block)
          block&.call || "no block"
        end
      end
      hook = hook_class.new

      result_with_block = hook.call(double("Task"), :test) { "block executed" }
      result_without_block = hook.call(double("Task"), :test)

      expect(result_with_block).to eq("block executed")
      expect(result_without_block).to eq("no block")
    end
  end
end

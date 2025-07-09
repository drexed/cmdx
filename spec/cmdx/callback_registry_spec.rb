# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CallbackRegistry do
  describe "#initialize" do
    context "when initialized without arguments" do
      it "creates an empty registry" do
        registry = described_class.new

        expect(registry.to_h).to be_empty
        expect(registry.to_h.keys).to eq([])
      end
    end

    context "when initialized with existing registry" do
      let(:source_registry) do
        registry = described_class.new
        registry.register(:before_validation, :check_permissions)
        registry.register(:on_success, :log_success, if: :important?)
        registry
      end

      it "copies callbacks from source registry" do
        new_registry = described_class.new(source_registry)

        expect(new_registry.to_h[:before_validation]).to eq([[[:check_permissions], {}]])
        expect(new_registry.to_h[:on_success]).to eq([[[:log_success], { if: :important? }]])
      end

      it "creates independent copy of callback definitions" do
        new_registry = described_class.new(source_registry)
        new_registry.register(:before_validation, :additional_callback)

        expect(source_registry.to_h[:before_validation]).to eq([[[:check_permissions], {}]])
        expect(new_registry.to_h[:before_validation]).to eq([[[:check_permissions], {}], [[:additional_callback], {}]])
      end
    end

    context "when initialized with hash" do
      let(:source_hash) do
        {
          before_validation: [[:check_permissions, {}]],
          on_success: [[:log_success, {}]]
        }
      end

      it "copies callbacks from hash" do
        registry = described_class.new(source_hash)

        expect(registry.to_h[:before_validation]).to eq([[:check_permissions, {}]])
        expect(registry.to_h[:on_success]).to eq([[:log_success, {}]])
      end
    end

    context "when initialized with nil" do
      it "creates empty registry" do
        registry = described_class.new(nil)

        expect(registry.to_h).to be_empty
      end
    end
  end

  describe "Hash behavior" do
    let(:registry) { described_class.new }

    it "provides hash-like access through to_h" do
      expect(registry.to_h).to respond_to(:keys)
      expect(registry.to_h).to respond_to(:values)
      expect(registry.to_h).to respond_to(:each)
    end

    it "supports registration and access" do
      registry.register(:test_callback, :method_name)

      expect(registry.to_h[:test_callback]).to eq([[[:method_name], {}]])
    end

    it "supports key checking" do
      registry.register(:existing, :method)

      expect(registry.to_h.key?(:existing)).to be(true)
      expect(registry.to_h.key?(:missing)).to be(false)
    end

    it "supports iteration through to_h" do
      registry.register(:callback1, :method1)
      registry.register(:callback2, :method2)

      keys = []
      values = []
      registry.to_h.each do |k, v|
        keys << k
        values << v
      end

      expect(keys).to contain_exactly(:callback1, :callback2)
      expect(values).to contain_exactly([[[:method1], {}]], [[[:method2], {}]])
    end

    it "supports size operations through to_h" do
      expect(registry.to_h.size).to eq(0)
      expect(registry.to_h).to be_empty

      registry.register(:callback, :method)
      expect(registry.to_h.size).to eq(1)
      expect(registry.to_h).not_to be_empty
    end
  end

  describe "#register" do
    let(:registry) { described_class.new }

    context "when registering single callable" do
      it "registers method symbol" do
        registry.register(:before_validation, :check_permissions)

        expect(registry.to_h[:before_validation]).to eq([[[:check_permissions], {}]])
      end

      it "registers proc" do
        proc_callable = proc { "test" }
        registry.register(:on_success, proc_callable)

        expect(registry.to_h[:on_success]).to eq([[[proc_callable], {}]])
      end

      it "registers callback instance" do
        callback = CMDx::Callback.new
        registry.register(:on_failure, callback)

        expect(registry.to_h[:on_failure]).to eq([[[callback], {}]])
      end
    end

    context "when registering multiple callables" do
      it "registers multiple method symbols" do
        registry.register(:before_validation, :check_permissions, :validate_input)

        expect(registry.to_h[:before_validation]).to eq([[%i[check_permissions validate_input], {}]])
      end

      it "registers mixed callable types" do
        proc_callable = proc { "test" }
        registry.register(:on_success, :log_success, proc_callable)

        expect(registry.to_h[:on_success]).to eq([[[:log_success, proc_callable], {}]])
      end
    end

    context "when registering with block" do
      it "includes block as callable" do
        registry.register(:before_validation) { "block execution" }

        callables = registry.to_h[:before_validation].first.first
        expect(callables.size).to eq(1)
        expect(callables.first).to be_a(Proc)
        expect(callables.first.call).to eq("block execution")
      end

      it "combines callables with block" do
        registry.register(:on_success, :log_method) { "block execution" }

        callables = registry.to_h[:on_success].first.first
        expect(callables.size).to eq(2)
        expect(callables.first).to eq(:log_method)
        expect(callables.last).to be_a(Proc)
      end
    end

    context "when registering with conditions" do
      it "registers with if condition" do
        registry.register(:on_success, :log_success, if: :important?)

        expect(registry.to_h[:on_success]).to eq([[[:log_success], { if: :important? }]])
      end

      it "registers with unless condition" do
        registry.register(:on_failure, :alert_admin, unless: :test_env?)

        expect(registry.to_h[:on_failure]).to eq([[[:alert_admin], { unless: :test_env? }]])
      end

      it "registers with multiple conditions" do
        registry.register(:on_success, :log_success, if: :important?, unless: :silent?)

        expect(registry.to_h[:on_success]).to eq([[[:log_success], { if: :important?, unless: :silent? }]])
      end

      it "registers with proc conditions" do
        condition_proc = proc { true }
        registry.register(:on_success, :log_success, if: condition_proc)

        expect(registry.to_h[:on_success]).to eq([[[:log_success], { if: condition_proc }]])
      end
    end

    context "when registering to existing callback type" do
      it "appends to existing callbacks" do
        registry.register(:before_validation, :first_callback)
        registry.register(:before_validation, :second_callback)

        expect(registry.to_h[:before_validation]).to eq([
                                                          [[:first_callback], {}],
                                                          [[:second_callback], {}]
                                                        ])
      end

      it "prevents duplicate callback registrations" do
        registry.register(:before_validation, :check_permissions)
        registry.register(:before_validation, :check_permissions)

        expect(registry.to_h[:before_validation]).to eq([[[:check_permissions], {}]])
      end

      it "allows same callable with different conditions" do
        registry.register(:on_success, :log_success, if: :important?)
        registry.register(:on_success, :log_success, unless: :silent?)

        expect(registry.to_h[:on_success]).to eq([
                                                   [[:log_success], { if: :important? }],
                                                   [[:log_success], { unless: :silent? }]
                                                 ])
      end
    end

    context "when registering uninstantiated callback classes" do
      let(:callback_class) do
        Class.new(CMDx::Callback) do
          def call(task, type)
            task.context.callback_executed = "#{type}_executed"
          end
        end
      end

      it "registers callback class" do
        registry.register(:test_callback, callback_class)

        expect(registry.to_h[:test_callback]).to eq([[[callback_class], {}]])
      end

      it "registers callback class with conditions" do
        registry.register(:test_callback, callback_class, if: :should_execute?)

        expect(registry.to_h[:test_callback]).to eq([[[callback_class], { if: :should_execute? }]])
      end

      it "registers multiple callback classes" do
        other_callback_class = Class.new(CMDx::Callback) do
          def call(task, _type)
            task.context.other_executed = true
          end
        end

        registry.register(:test_callback, callback_class, other_callback_class)

        expect(registry.to_h[:test_callback]).to eq([[[callback_class, other_callback_class], {}]])
      end

      it "registers mixed callback types including classes" do
        proc_callback = proc { "test" }
        registry.register(:mixed_callback, :method_name, callback_class, proc_callback)

        expect(registry.to_h[:mixed_callback]).to eq([[[
                                                       :method_name,
                                                       callback_class,
                                                       proc_callback
                                                     ], {}]])
      end
    end

    it "returns self for method chaining" do
      result = registry.register(:test, :method)

      expect(result).to eq(registry)
    end

    it "supports chained registration" do
      registry.register(:before_validation, :check_permissions)
              .register(:on_success, :log_success)
              .register(:on_failure, :alert_admin)

      expect(registry.to_h.keys).to contain_exactly(:before_validation, :on_success, :on_failure)
    end
  end

  describe "#call" do
    let(:registry) { described_class.new }
    let(:task) { mock_task }

    before do
      allow(task).to receive(:__cmdx_eval).and_return(true)
      allow(task).to receive(:__cmdx_try)
    end

    context "when callback type does not exist" do
      it "does nothing" do
        expect { registry.call(task, :before_validation) }.not_to raise_error
      end
    end

    context "when callback type exists" do
      before do
        registry.register(:before_validation, :method_name)
      end

      it "evaluates callback conditions" do
        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_eval).with({})
      end

      it "executes callable when conditions pass" do
        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_try).with(:method_name)
      end

      it "skips execution when conditions fail" do
        allow(task).to receive(:__cmdx_eval).and_return(false)

        registry.call(task, :before_validation)

        expect(task).not_to have_received(:__cmdx_try)
      end
    end

    context "when executing multiple callables" do
      before do
        registry.register(:before_validation, :first_method, :second_method)
      end

      it "executes all callables in order" do
        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_try).with(:first_method).ordered
        expect(task).to have_received(:__cmdx_try).with(:second_method).ordered
      end
    end

    context "when executing multiple callback definitions" do
      before do
        registry.register(:before_validation, :first_callback)
        registry.register(:before_validation, :second_callback, if: :condition?)
      end

      it "evaluates conditions for each definition" do
        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_eval).with({}).ordered
        expect(task).to have_received(:__cmdx_eval).with({ if: :condition? }).ordered
      end

      it "executes callbacks with passing conditions" do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(true)
        allow(task).to receive(:__cmdx_eval).with({ if: :condition? }).and_return(false)

        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_try).with(:first_callback)
        expect(task).not_to have_received(:__cmdx_try).with(:second_callback)
      end
    end

    context "when executing Callback instances" do
      let(:callback_instance) { double("CallbackInstance") }

      before do
        allow(callback_instance).to receive(:is_a?).with(CMDx::Callback).and_return(true)
        allow(callback_instance).to receive(:call)
        registry.register(:before_validation, callback_instance)
      end

      it "calls callback instance directly" do
        registry.call(task, :before_validation)

        expect(callback_instance).to have_received(:call).with(task)
        expect(task).not_to have_received(:__cmdx_try)
      end
    end

    context "when executing uninstantiated callback classes" do
      let(:callback_class) { double("CallbackClass") }

      before do
        allow(task).to receive(:context).and_return(double("Context").as_null_object)
        allow(callback_class).to receive(:call)
        registry.register(:before_validation, callback_class)
      end

      it "calls callback class directly" do
        registry.call(task, :before_validation)

        expect(callback_class).to have_received(:call).with(task).at_least(:once)
      end

      it "does not pass callback class to __cmdx_try" do
        registry.call(task, :before_validation)

        expect(task).not_to have_received(:__cmdx_try).with(callback_class)
      end

      it "handles callback class with conditions" do
        registry.register(:before_validation, callback_class, if: :condition?)

        registry.call(task, :before_validation)

        expect(callback_class).to have_received(:call).with(task).at_least(:once)
      end

      it "skips callback class when conditions fail" do
        allow(task).to receive(:__cmdx_eval).and_return(false)
        registry.register(:before_validation, callback_class, if: :condition?)

        registry.call(task, :before_validation)

        expect(callback_class).not_to have_received(:call)
      end

      it "executes multiple callback classes in order" do
        callback_class2 = double("CallbackClass2")
        allow(callback_class2).to receive(:call)
        registry.register(:before_validation, callback_class, callback_class2)

        registry.call(task, :before_validation)

        expect(callback_class).to have_received(:call).with(task).at_least(:once)
        expect(callback_class2).to have_received(:call).with(task).at_least(:once)
      end

      it "handles mixed callback types including classes" do
        proc_callback = proc { "test" }
        callback_instance = double("CallbackInstance")
        allow(callback_instance).to receive(:is_a?).with(CMDx::Callback).and_return(true)
        allow(callback_instance).to receive(:call)

        registry.register(:before_validation, :method_name, callback_class, callback_instance, proc_callback)

        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_try).with(:method_name)
        expect(callback_class).to have_received(:call).with(task).at_least(:once)
        expect(callback_instance).to have_received(:call).with(task)
        expect(task).to have_received(:__cmdx_try).with(proc_callback).at_least(:once)
      end
    end

    context "when executing mixed callable types" do
      let(:callback_instance) { double("CallbackInstance") }
      let(:proc_callable) { proc { "test" } }

      before do
        allow(callback_instance).to receive(:is_a?).with(CMDx::Callback).and_return(true)
        allow(callback_instance).to receive(:call)
        registry.register(:before_validation, :method_name, callback_instance, proc_callable)
      end

      it "handles each callable appropriately" do
        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_try).with(:method_name).at_least(:once)
        expect(callback_instance).to have_received(:call).with(task).at_least(:once)
        expect(task).to have_received(:__cmdx_try).with(proc_callable).at_least(:once)
      end
    end

    context "when callback definitions have complex conditions" do
      it "executes callbacks based on their individual conditions" do
        registry.register(:before_validation, :first_callback, if: :condition_a?)
        registry.register(:before_validation, :second_callback, unless: :condition_b?)
        registry.register(:before_validation, :third_callback, if: :condition_c?)

        allow(task).to receive(:__cmdx_eval).with({ if: :condition_a? }).and_return(true)
        allow(task).to receive(:__cmdx_eval).with({ unless: :condition_b? }).and_return(false)
        allow(task).to receive(:__cmdx_eval).with({ if: :condition_c? }).and_return(true)

        registry.call(task, :before_validation)

        expect(task).to have_received(:__cmdx_try).with(:first_callback)
        expect(task).not_to have_received(:__cmdx_try).with(:second_callback)
        expect(task).to have_received(:__cmdx_try).with(:third_callback)
      end
    end

    context "when registry is empty" do
      it "handles empty registry gracefully" do
        expect { registry.call(task, :before_validation) }.not_to raise_error
      end
    end

    context "when testing edge cases" do
      it "handles missing callback type gracefully" do
        expect { registry.call(task, :before_validation) }.not_to raise_error
      end

      it "handles registry with registered callbacks" do
        registry.register(:before_validation, :method)

        expect { registry.call(task, :before_validation) }.not_to raise_error
        expect(task).to have_received(:__cmdx_try).with(:method)
      end
    end
  end

  describe "integration scenarios" do
    let(:registry) { described_class.new }
    let(:task) { mock_task }

    before do
      allow(task).to receive(:__cmdx_eval).and_return(true)
      allow(task).to receive(:__cmdx_try)
    end

    it "supports complex callback registration and execution workflow" do
      # Register various callback types
      registry.register(:before_validation, :setup_context)
      registry.register(:before_validation, :check_permissions, if: :authenticated?)
      registry.register(:on_success, :log_success, :notify_users)
      registry.register(:on_failure, :rollback_changes, unless: :read_only?)

      # Execute before_validation callbacks
      registry.call(task, :before_validation)

      expect(task).to have_received(:__cmdx_try).with(:setup_context)
      expect(task).to have_received(:__cmdx_try).with(:check_permissions)

      # Reset for next execution
      allow(task).to receive(:__cmdx_try)

      # Execute on_success callbacks
      registry.call(task, :on_success)

      expect(task).to have_received(:__cmdx_try).with(:log_success)
      expect(task).to have_received(:__cmdx_try).with(:notify_users)
    end

    it "maintains callback execution order across multiple registrations" do
      registry.register(:before_validation, :first)
      registry.register(:before_validation, :second)
      registry.register(:before_validation, :third)

      registry.call(task, :before_validation)

      expect(task).to have_received(:__cmdx_try).with(:first).ordered
      expect(task).to have_received(:__cmdx_try).with(:second).ordered
      expect(task).to have_received(:__cmdx_try).with(:third).ordered
    end

    it "handles callback registry copying and modification" do
      original_registry = described_class.new
      original_registry.register(:before_validation, :original_method)

      copied_registry = original_registry.dup
      copied_registry.register(:before_validation, :copied_method)

      original_registry.call(task, :before_validation)
      expect(task).to have_received(:__cmdx_try).with(:original_method)

      task_copy = double("TaskCopy")
      allow(task_copy).to receive(:__cmdx_try)
      allow(task_copy).to receive(:__cmdx_eval).and_return(true)

      copied_registry.call(task_copy, :before_validation)
      expect(task_copy).to have_received(:__cmdx_try).with(:original_method)
      expect(task_copy).to have_received(:__cmdx_try).with(:copied_method)
    end

    it "supports mixed callback types in complex scenarios" do
      callback_instance = double("CallbackInstance")
      allow(callback_instance).to receive(:is_a?).with(CMDx::Callback).and_return(true)
      allow(callback_instance).to receive(:call)

      proc_callback = proc { "test_proc" }
      callback_class = double("CallbackClass")
      allow(callback_class).to receive(:call)

      registry.register(:before_validation, :method_callback, callback_instance, proc_callback, callback_class)

      registry.call(task, :before_validation)

      expect(task).to have_received(:__cmdx_try).with(:method_callback)
      expect(callback_instance).to have_received(:call).with(task)
      expect(task).to have_received(:__cmdx_try).with(proc_callback).at_least(:once)
      expect(callback_class).to have_received(:call).with(task).at_least(:once)
    end
  end
end

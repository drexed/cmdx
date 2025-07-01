# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::HookRegistry do
  describe "#initialize" do
    context "when initialized without arguments" do
      it "creates an empty registry" do
        registry = described_class.new

        expect(registry).to be_empty
        expect(registry.keys).to eq([])
      end
    end

    context "when initialized with existing registry" do
      let(:source_registry) do
        registry = described_class.new
        registry[:before_validation] = [[:check_permissions, {}]]
        registry[:on_success] = [[:log_success, { if: :important? }]]
        registry
      end

      it "copies hooks from source registry" do
        new_registry = described_class.new(source_registry)

        expect(new_registry[:before_validation]).to eq([[:check_permissions, {}]])
        expect(new_registry[:on_success]).to eq([[:log_success, { if: :important? }]])
      end

      it "creates independent copy of hook definitions" do
        new_registry = described_class.new(source_registry)
        new_registry[:before_validation] << [:additional_hook, {}]

        expect(source_registry[:before_validation]).to eq([[:check_permissions, {}]])
        expect(new_registry[:before_validation]).to eq([[:check_permissions, {}], [:additional_hook, {}]])
      end
    end

    context "when initialized with hash" do
      let(:source_hash) do
        {
          before_validation: [[:check_permissions, {}]],
          on_success: [[:log_success, {}]]
        }
      end

      it "copies hooks from hash" do
        registry = described_class.new(source_hash)

        expect(registry[:before_validation]).to eq([[:check_permissions, {}]])
        expect(registry[:on_success]).to eq([[:log_success, {}]])
      end
    end

    context "when initialized with nil" do
      it "creates empty registry" do
        registry = described_class.new(nil)

        expect(registry).to be_empty
      end
    end
  end

  describe "Hash behavior" do
    let(:registry) { described_class.new }

    it "behaves like a Hash" do
      expect(registry).to be_a(Hash)
      expect(registry).to respond_to(:keys)
      expect(registry).to respond_to(:values)
      expect(registry).to respond_to(:each)
    end

    it "supports hash assignment" do
      registry[:test_hook] = [[:method_name, {}]]

      expect(registry[:test_hook]).to eq([[:method_name, {}]])
    end

    it "supports hash key checking" do
      registry[:existing] = [[:method, {}]]

      expect(registry.key?(:existing)).to be(true)
      expect(registry.key?(:missing)).to be(false)
    end

    it "supports hash iteration" do
      registry[:hook1] = [[:method1, {}]]
      registry[:hook2] = [[:method2, {}]]

      keys = []
      values = []
      registry.each do |k, v|
        keys << k
        values << v
      end

      expect(keys).to contain_exactly(:hook1, :hook2)
      expect(values).to contain_exactly([[:method1, {}]], [[:method2, {}]])
    end

    it "supports hash size operations" do
      expect(registry.size).to eq(0)
      expect(registry).to be_empty

      registry[:hook] = [[:method, {}]]
      expect(registry.size).to eq(1)
      expect(registry).not_to be_empty
    end
  end

  describe "#register" do
    let(:registry) { described_class.new }

    context "when registering single callable" do
      it "registers method symbol" do
        registry.register(:before_validation, :check_permissions)

        expect(registry[:before_validation]).to eq([[[:check_permissions], {}]])
      end

      it "registers proc" do
        proc_callable = proc { "test" }
        registry.register(:on_success, proc_callable)

        expect(registry[:on_success]).to eq([[[proc_callable], {}]])
      end

      it "registers hook instance" do
        hook = CMDx::Hook.new
        registry.register(:on_failure, hook)

        expect(registry[:on_failure]).to eq([[[hook], {}]])
      end
    end

    context "when registering multiple callables" do
      it "registers multiple method symbols" do
        registry.register(:before_validation, :check_permissions, :validate_input)

        expect(registry[:before_validation]).to eq([[%i[check_permissions validate_input], {}]])
      end

      it "registers mixed callable types" do
        proc_callable = proc { "test" }
        registry.register(:on_success, :log_success, proc_callable)

        expect(registry[:on_success]).to eq([[[:log_success, proc_callable], {}]])
      end
    end

    context "when registering with block" do
      it "includes block as callable" do
        registry.register(:before_validation) { "block execution" }

        callables = registry[:before_validation].first.first
        expect(callables.size).to eq(1)
        expect(callables.first).to be_a(Proc)
        expect(callables.first.call).to eq("block execution")
      end

      it "combines callables with block" do
        registry.register(:on_success, :log_method) { "block execution" }

        callables = registry[:on_success].first.first
        expect(callables.size).to eq(2)
        expect(callables.first).to eq(:log_method)
        expect(callables.last).to be_a(Proc)
      end
    end

    context "when registering with conditions" do
      it "registers with if condition" do
        registry.register(:on_success, :log_success, if: :important?)

        expect(registry[:on_success]).to eq([[[:log_success], { if: :important? }]])
      end

      it "registers with unless condition" do
        registry.register(:on_failure, :alert_admin, unless: :test_env?)

        expect(registry[:on_failure]).to eq([[[:alert_admin], { unless: :test_env? }]])
      end

      it "registers with multiple conditions" do
        registry.register(:on_success, :log_success, if: :important?, unless: :silent?)

        expect(registry[:on_success]).to eq([[[:log_success], { if: :important?, unless: :silent? }]])
      end

      it "registers with proc conditions" do
        condition_proc = proc { true }
        registry.register(:on_success, :log_success, if: condition_proc)

        expect(registry[:on_success]).to eq([[[:log_success], { if: condition_proc }]])
      end
    end

    context "when registering to existing hook type" do
      it "appends to existing hooks" do
        registry.register(:before_validation, :first_hook)
        registry.register(:before_validation, :second_hook)

        expect(registry[:before_validation]).to eq([
                                                     [[:first_hook], {}],
                                                     [[:second_hook], {}]
                                                   ])
      end

      it "prevents duplicate hook registrations" do
        registry.register(:before_validation, :check_permissions)
        registry.register(:before_validation, :check_permissions)

        expect(registry[:before_validation]).to eq([[[:check_permissions], {}]])
      end

      it "allows same callable with different conditions" do
        registry.register(:on_success, :log_success, if: :important?)
        registry.register(:on_success, :log_success, unless: :silent?)

        expect(registry[:on_success]).to eq([
                                              [[:log_success], { if: :important? }],
                                              [[:log_success], { unless: :silent? }]
                                            ])
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

      expect(registry.keys).to contain_exactly(:before_validation, :on_success, :on_failure)
    end
  end

  describe "#call" do
    let(:registry) { described_class.new }
    let(:task) { double("Task") }

    before do
      allow(task).to receive(:__cmdx_eval).and_return(true)
      allow(task).to receive(:__cmdx_try)
    end

    context "when hook type does not exist" do
      it "does nothing" do
        registry.call(task, :non_existent_hook)

        expect(task).not_to have_received(:__cmdx_eval)
        expect(task).not_to have_received(:__cmdx_try)
      end
    end

    context "when hook type exists" do
      before do
        registry.register(:test_hook, :method_name)
      end

      it "evaluates hook conditions" do
        registry.call(task, :test_hook)

        expect(task).to have_received(:__cmdx_eval).with({})
      end

      it "executes callable when conditions pass" do
        registry.call(task, :test_hook)

        expect(task).to have_received(:__cmdx_try).with(:method_name)
      end

      it "skips execution when conditions fail" do
        allow(task).to receive(:__cmdx_eval).and_return(false)

        registry.call(task, :test_hook)

        expect(task).not_to have_received(:__cmdx_try)
      end
    end

    context "when executing multiple callables" do
      before do
        registry.register(:test_hook, :first_method, :second_method)
      end

      it "executes all callables in order" do
        registry.call(task, :test_hook)

        expect(task).to have_received(:__cmdx_try).with(:first_method).ordered
        expect(task).to have_received(:__cmdx_try).with(:second_method).ordered
      end
    end

    context "when executing multiple hook definitions" do
      before do
        registry.register(:test_hook, :first_hook)
        registry.register(:test_hook, :second_hook, if: :condition?)
      end

      it "evaluates conditions for each definition" do
        registry.call(task, :test_hook)

        expect(task).to have_received(:__cmdx_eval).with({}).ordered
        expect(task).to have_received(:__cmdx_eval).with({ if: :condition? }).ordered
      end

      it "executes hooks with passing conditions" do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(true)
        allow(task).to receive(:__cmdx_eval).with({ if: :condition? }).and_return(false)

        registry.call(task, :test_hook)

        expect(task).to have_received(:__cmdx_try).with(:first_hook)
        expect(task).not_to have_received(:__cmdx_try).with(:second_hook)
      end
    end

    context "when executing Hook instances" do
      let(:hook_instance) { double("HookInstance") }

      before do
        allow(hook_instance).to receive(:is_a?).with(CMDx::Hook).and_return(true)
        allow(hook_instance).to receive(:call)
        registry.register(:test_hook, hook_instance)
      end

      it "calls hook instance directly" do
        registry.call(task, :test_hook)

        expect(hook_instance).to have_received(:call).with(task, :test_hook)
        expect(task).not_to have_received(:__cmdx_try)
      end
    end

    context "when executing mixed callable types" do
      let(:hook_instance) { double("HookInstance") }
      let(:proc_callable) { proc { "test" } }

      before do
        allow(hook_instance).to receive(:is_a?).with(CMDx::Hook).and_return(true)
        allow(hook_instance).to receive(:call)
        registry.register(:test_hook, :method_name, hook_instance, proc_callable)
      end

      it "handles each callable appropriately" do
        registry.call(task, :test_hook)

        expect(task).to have_received(:__cmdx_try).with(:method_name).at_least(:once)
        expect(hook_instance).to have_received(:call).with(task, :test_hook).at_least(:once)
        expect(task).to have_received(:__cmdx_try).with(proc_callable).at_least(:once)
      end
    end

    context "when hook definitions have complex conditions" do
      before do
        registry.register(:complex_hook, :always_run)
        registry.register(:complex_hook, :conditional_run, if: :important?)
        registry.register(:complex_hook, :never_run, unless: :always_true)
      end

      it "executes hooks based on their individual conditions" do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(true)
        allow(task).to receive(:__cmdx_eval).with({ if: :important? }).and_return(true)
        allow(task).to receive(:__cmdx_eval).with({ unless: :always_true }).and_return(false)

        registry.call(task, :complex_hook)

        expect(task).to have_received(:__cmdx_try).with(:always_run)
        expect(task).to have_received(:__cmdx_try).with(:conditional_run)
        expect(task).not_to have_received(:__cmdx_try).with(:never_run)
      end
    end

    context "when registry is empty" do
      it "handles empty registry gracefully" do
        expect { registry.call(task, :any_hook) }.not_to raise_error
      end
    end

    context "when hook type value is nil" do
      before do
        registry[:test_hook] = nil
      end

      it "handles nil gracefully" do
        expect { registry.call(task, :test_hook) }.not_to raise_error
      end
    end

    context "when hook type value is not an array" do
      before do
        registry[:test_hook] = "not an array"
      end

      it "wraps non-array values in array" do
        registry.call(task, :test_hook)

        expect(task).to have_received(:__cmdx_eval).once
      end
    end
  end

  describe "integration scenarios" do
    let(:registry) { described_class.new }
    let(:task) { double("Task") }

    before do
      allow(task).to receive(:__cmdx_eval).and_return(true)
      allow(task).to receive(:__cmdx_try)
    end

    it "supports complex hook registration and execution workflow" do
      # Register various hook types
      registry.register(:before_validation, :setup_context)
      registry.register(:before_validation, :check_permissions, if: :authenticated?)
      registry.register(:on_success, :log_success, :notify_users)
      registry.register(:on_failure, :rollback_changes, unless: :read_only?)

      # Execute before_validation hooks
      registry.call(task, :before_validation)

      expect(task).to have_received(:__cmdx_try).with(:setup_context)
      expect(task).to have_received(:__cmdx_try).with(:check_permissions)

      # Reset for next execution
      allow(task).to receive(:__cmdx_try)

      # Execute on_success hooks
      registry.call(task, :on_success)

      expect(task).to have_received(:__cmdx_try).with(:log_success)
      expect(task).to have_received(:__cmdx_try).with(:notify_users)
    end

    it "maintains hook execution order across multiple registrations" do
      registry.register(:ordered_hook, :first)
      registry.register(:ordered_hook, :second)
      registry.register(:ordered_hook, :third)

      registry.call(task, :ordered_hook)

      expect(task).to have_received(:__cmdx_try).with(:first).ordered
      expect(task).to have_received(:__cmdx_try).with(:second).ordered
      expect(task).to have_received(:__cmdx_try).with(:third).ordered
    end

    it "handles hook registry copying and modification" do
      original = described_class.new
      original.register(:shared_hook, :original_method)

      copy = described_class.new(original)
      copy.register(:shared_hook, :additional_method)
      copy.register(:new_hook, :new_method)

      # Test original registry unchanged
      original.call(task, :shared_hook)
      expect(task).to have_received(:__cmdx_try).with(:original_method).at_least(:once)
      expect(task).not_to have_received(:__cmdx_try).with(:additional_method)

      # Reset for copy execution
      allow(task).to receive(:__cmdx_try)

      # Test copy has both methods
      copy.call(task, :shared_hook)
      expect(task).to have_received(:__cmdx_try).with(:original_method).at_least(:once)
      expect(task).to have_received(:__cmdx_try).with(:additional_method).at_least(:once)
    end
  end
end

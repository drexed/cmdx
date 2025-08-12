# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  let(:task_class) { create_task_class(name: "TestTask") }
  let(:task) { task_class.new }
  let(:context_hash) { { foo: "bar", baz: 42 } }

  describe "#initialize" do
    context "with no arguments" do
      it "initializes with default values" do
        expect(task.attributes).to eq({})
        expect(task.errors).to be_a(CMDx::Errors)
        expect(task.errors).to be_empty
        expect(task.id).to be_a(String)
        expect(task.context).to be_a(CMDx::Context)
        expect(task.context.to_h).to eq({})
        expect(task.result).to be_a(CMDx::Result)
        expect(task.result.task).to eq(task)
        expect(task.chain).to be_a(CMDx::Chain)
      end

      it "generates unique IDs for different instances" do
        task1 = task_class.new
        task2 = task_class.new

        expect(task1.id).not_to eq(task2.id)
      end
    end

    context "with context hash" do
      let(:task) { task_class.new(context_hash) }

      it "initializes context with provided hash" do
        expect(task.context.to_h).to eq(context_hash)
      end
    end

    context "with context object" do
      let(:context_obj) { CMDx::Context.new(context_hash) }
      let(:task) { task_class.new(context_obj) }

      it "uses the provided context object" do
        expect(task.context).to eq(context_obj)
        expect(task.context.to_h).to eq(context_hash)
      end
    end

    context "with object that responds to context" do
      let(:context_wrapper) { instance_double("MockContextWrapper", context: context_hash) }
      let(:task) { task_class.new(context_wrapper) }

      it "extracts context from the wrapper object" do
        expect(task.context.to_h).to eq(context_hash)
      end
    end

    it "calls Deprecator.restrict" do
      expect(CMDx::Deprecator).to receive(:restrict).with(an_instance_of(task_class))

      task_class.new
    end
  end

  describe "aliases" do
    it "aliases ctx to context" do
      expect(task.ctx).to eq(task.context)
    end

    it "aliases res to result" do
      expect(task.res).to eq(task.result)
    end
  end

  describe "delegated methods" do
    it "delegates skip! to result" do
      expect(task.result).to receive(:skip!).with("reason", metadata: "data")

      task.skip!("reason", metadata: "data")
    end

    it "delegates fail! to result" do
      expect(task.result).to receive(:fail!).with("reason", metadata: "data")

      task.fail!("reason", metadata: "data")
    end

    it "delegates throw! to result" do
      expect(task.result).to receive(:throw!).with("reason", metadata: "data")

      task.throw!("reason", metadata: "data")
    end
  end

  describe ".settings" do
    context "when called for the first time" do
      it "returns default settings with required keys" do
        settings = task_class.settings

        expect(settings).to be_a(Hash)
        expect(settings).to have_key(:attributes)
        expect(settings[:attributes]).to be_a(CMDx::AttributeRegistry)
        expect(settings).to have_key(:deprecate)
        expect(settings[:deprecate]).to be false
        expect(settings).to have_key(:tags)
        expect(settings[:tags]).to eq([])
      end

      it "excludes logger from CMDx configuration" do
        allow(CMDx.configuration).to receive(:to_h).and_return({ logger: "test_logger", other: "value" })

        settings = task_class.settings

        expect(settings).not_to have_key(:logger)
        expect(settings).to have_key(:other)
      end
    end

    context "when superclass has configuration" do
      let(:parent_class) { create_task_class(name: "ParentTask") }
      let(:child_class) { Class.new(parent_class) }

      before do
        # Define configuration method on parent class to simulate inheritance
        parent_class.define_singleton_method(:configuration) do
          { custom_setting: "parent_value" }
        end
      end

      it "inherits from superclass configuration" do
        child_settings = child_class.settings

        expect(child_settings[:custom_setting]).to eq("parent_value")
      end

      it "can override inherited settings" do
        child_settings = child_class.settings(custom_setting: "child_value")

        expect(child_settings[:custom_setting]).to eq("child_value")
      end
    end

    context "with custom options" do
      it "merges custom options with defaults" do
        settings = task_class.settings(custom_key: "custom_value", tags: ["tag1"])

        expect(settings[:custom_key]).to eq("custom_value")
        expect(settings[:tags]).to eq(["tag1"])
        expect(settings[:deprecate]).to be false
      end
    end

    it "memoizes settings" do
      settings1 = task_class.settings
      settings2 = task_class.settings

      expect(settings1).to be(settings2)
    end

    it "duplicates values to prevent mutation" do
      original_config = { test_array: [1, 2, 3] }
      allow(CMDx.configuration).to receive(:to_h).and_return(original_config)

      settings = task_class.settings
      settings[:test_array] << 4

      expect(original_config[:test_array]).to eq([1, 2, 3])
    end
  end

  describe ".register" do
    let(:mock_registry) { instance_double("MockRegistry") }

    before do
      allow(task_class.settings).to receive(:[]).with(:attributes).and_return(mock_registry)
      allow(task_class.settings).to receive(:[]).with(:callbacks).and_return(mock_registry)
      allow(task_class.settings).to receive(:[]).with(:coercions).and_return(mock_registry)
      allow(task_class.settings).to receive(:[]).with(:middlewares).and_return(mock_registry)
      allow(task_class.settings).to receive(:[]).with(:validators).and_return(mock_registry)
    end

    context "with :attribute type" do
      it "registers with attribute registry" do
        expect(mock_registry).to receive(:register).with("object", "arg1", "arg2")

        task_class.register(:attribute, "object", "arg1", "arg2")
      end
    end

    context "with :callback type" do
      it "registers with callback registry" do
        expect(mock_registry).to receive(:register).with("object", "arg1", "arg2")

        task_class.register(:callback, "object", "arg1", "arg2")
      end
    end

    context "with :coercion type" do
      it "registers with coercion registry" do
        expect(mock_registry).to receive(:register).with("object", "arg1", "arg2")

        task_class.register(:coercion, "object", "arg1", "arg2")
      end
    end

    context "with :middleware type" do
      it "registers with middleware registry" do
        expect(mock_registry).to receive(:register).with("object", "arg1", "arg2")

        task_class.register(:middleware, "object", "arg1", "arg2")
      end
    end

    context "with :validator type" do
      it "registers with validator registry" do
        expect(mock_registry).to receive(:register).with("object", "arg1", "arg2")

        task_class.register(:validator, "object", "arg1", "arg2")
      end
    end

    context "with unknown type" do
      it "raises an error" do
        expect { task_class.register(:unknown, "object") }.to raise_error("unknown register type :unknown")
      end
    end
  end

  describe ".attribute" do
    it "defines and registers an attribute" do
      mock_attribute = instance_double(CMDx::Attribute)
      expect(CMDx::Attribute).to receive(:define).with("name", "arg1", "arg2").and_return(mock_attribute)
      expect(task_class).to receive(:register).with(:attribute, mock_attribute)

      task_class.attribute("name", "arg1", "arg2")
    end
  end

  describe ".attributes" do
    it "defines and registers multiple attributes" do
      mock_attributes = instance_double(CMDx::Attribute)
      expect(CMDx::Attribute).to receive(:defines).with("arg1", "arg2").and_return(mock_attributes)
      expect(task_class).to receive(:register).with(:attribute, mock_attributes)

      task_class.attributes("arg1", "arg2")
    end
  end

  describe ".optional" do
    it "defines and registers optional attributes" do
      mock_attribute = instance_double(CMDx::Attribute)
      expect(CMDx::Attribute).to receive(:optional).with("arg1", "arg2").and_return(mock_attribute)
      expect(task_class).to receive(:register).with(:attribute, mock_attribute)

      task_class.optional("arg1", "arg2")
    end
  end

  describe ".required" do
    it "defines and registers required attributes" do
      mock_attribute = instance_double(CMDx::Attribute)
      expect(CMDx::Attribute).to receive(:required).with("arg1", "arg2").and_return(mock_attribute)
      expect(task_class).to receive(:register).with(:attribute, mock_attribute)

      task_class.required("arg1", "arg2")
    end
  end

  describe "callback methods" do
    CMDx::CallbackRegistry::TYPES.each do |callback_type|
      describe ".#{callback_type}" do
        it "registers the callback" do
          expect(task_class).to receive(:register).with(:callback, callback_type, "callable1", "callable2", option: "value")

          task_class.public_send(callback_type, "callable1", "callable2", option: "value")
        end

        it "accepts a block" do
          block = proc { "test" }
          expect(task_class).to receive(:register).with(:callback, callback_type, option: "value") do |*_args, &passed_block|
            expect(passed_block).to eq(block)
          end

          task_class.public_send(callback_type, option: "value", &block)
        end
      end
    end
  end

  describe ".execute" do
    let(:mock_task) { instance_double(described_class, result: "result") }

    it "creates new task instance and executes with raise: false" do
      expect(task_class).to receive(:new).with("arg1", "arg2").and_return(mock_task)
      expect(mock_task).to receive(:execute).with(raise: false)

      result = task_class.execute("arg1", "arg2")

      expect(result).to eq("result")
    end
  end

  describe ".execute!" do
    let(:mock_task) { instance_double(described_class, result: "result") }

    it "creates new task instance and executes with raise: true" do
      expect(task_class).to receive(:new).with("arg1", "arg2").and_return(mock_task)
      expect(mock_task).to receive(:execute).with(raise: true)

      result = task_class.execute!("arg1", "arg2")

      expect(result).to eq("result")
    end
  end

  describe "#execute" do
    context "with raise: false" do
      it "delegates to Worker.execute with raise: false" do
        expect(CMDx::Worker).to receive(:execute).with(task, raise: false)

        task.execute(raise: false)
      end
    end

    context "with raise: true" do
      it "delegates to Worker.execute with raise: true" do
        expect(CMDx::Worker).to receive(:execute).with(task, raise: true)

        task.execute(raise: true)
      end
    end

    context "with no arguments" do
      it "defaults to raise: false" do
        expect(CMDx::Worker).to receive(:execute).with(task, raise: false)

        task.execute
      end
    end
  end

  describe "#work" do
    it "raises UndefinedMethodError" do
      expect { task.work }.to raise_error(
        CMDx::UndefinedMethodError,
        /undefined method.*#work/
      )
    end

    it "includes the class name in the error message" do
      expect { task.work }.to raise_error(
        CMDx::UndefinedMethodError,
        /TestTask\d+#work/
      )
    end
  end

  describe "#logger" do
    context "when class settings has logger" do
      let(:class_logger) { instance_double(Logger) }

      before do
        allow(task.class).to receive(:settings).and_return({ logger: class_logger })
      end

      it "returns the class logger" do
        expect(task.logger).to eq(class_logger)
      end
    end

    context "when class settings has no logger" do
      let(:config_logger) { instance_double(Logger) }

      before do
        allow(task.class).to receive(:settings).and_return({})
        allow(CMDx.configuration).to receive(:logger).and_return(config_logger)
      end

      it "returns the configuration logger" do
        expect(task.logger).to eq(config_logger)
      end
    end
  end

  describe "#to_h" do
    let(:workflow_class) { Class.new(task_class) { include CMDx::Workflow } }
    let(:workflow_task) { workflow_class.new }

    before do
      allow(task.result).to receive(:index).and_return(5)
      allow(task.chain).to receive(:id).and_return("chain-123")
      allow(task.class).to receive(:settings).and_return({ tags: %w[tag1 tag2] })
    end

    context "when task is regular task" do
      it "returns hash representation" do
        result_hash = task.to_h

        expect(result_hash[:index]).to eq(5)
        expect(result_hash[:chain_id]).to eq("chain-123")
        expect(result_hash[:type]).to eq("Task")
        expect(result_hash[:tags]).to eq(%w[tag1 tag2])
        expect(result_hash[:class]).to be_a(String)
        expect(result_hash[:class]).to match(/TestTask\d+/)
        expect(result_hash[:id]).to eq(task.id)
      end
    end

    context "when task is workflow task" do
      before do
        allow(workflow_task.result).to receive(:index).and_return(3)
        allow(workflow_task.chain).to receive(:id).and_return("workflow-chain-456")
        allow(workflow_task.class).to receive(:settings).and_return({ tags: ["workflow"] })
      end

      it "returns hash with type 'Workflow'" do
        result_hash = workflow_task.to_h

        expect(result_hash[:index]).to eq(3)
        expect(result_hash[:chain_id]).to eq("workflow-chain-456")
        expect(result_hash[:type]).to eq("Workflow")
        expect(result_hash[:tags]).to eq(["workflow"])
        expect(result_hash[:class]).to be_a(String)
        expect(result_hash[:class]).to match(/TestTask\d+/)
        expect(result_hash[:id]).to eq(workflow_task.id)
      end
    end
  end

  describe "#to_s" do
    let(:hash_representation) { { key: "value", number: 42 } }

    before do
      allow(task).to receive(:to_h).and_return(hash_representation)
    end

    it "formats the hash using Utils::Format.to_str" do
      expect(CMDx::Utils::Format).to receive(:to_str).with(hash_representation).and_return("formatted_string")

      result = task.to_s

      expect(result).to eq("formatted_string")
    end
  end
end

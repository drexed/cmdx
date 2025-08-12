# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:task) { task_class.new }
  let(:context_hash) { { name: "test", value: 42 } }
  let(:task_with_context) { task_class.new(context_hash) }

  describe "#initialize" do
    it "initializes with empty context by default" do
      expect(task.context.to_h).to eq({})
    end

    it "initializes with provided context" do
      expect(task_with_context.context.to_h).to eq(context_hash)
    end

    it "sets up instance variables" do
      aggregate_failures do
        expect(task.attributes).to eq({})
        expect(task.errors).to be_a(CMDx::Errors)
        expect(task.errors).to be_empty
        expect(task.id).to be_a(String)
        expect(task.context).to be_a(CMDx::Context)
        expect(task.result).to be_a(CMDx::Result)
        expect(task.chain).to be_a(CMDx::Chain)
      end
    end

    it "generates unique IDs for different instances" do
      task1 = task_class.new
      task2 = task_class.new
      expect(task1.id).not_to eq(task2.id)
    end

    it "calls Deprecator.restrict" do
      allow(CMDx::Deprecator).to receive(:restrict)
      task_class.new
      expect(CMDx::Deprecator).to have_received(:restrict).with(kind_of(described_class))
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
      allow(task.result).to receive(:skip!)
      task.skip!("test reason")
      expect(task.result).to have_received(:skip!).with("test reason")
    end

    it "delegates fail! to result" do
      allow(task.result).to receive(:fail!)
      task.fail!("test reason")
      expect(task.result).to have_received(:fail!).with("test reason")
    end

    it "delegates throw! to result" do
      other_result = CMDx::Result.new(task_class.new)
      allow(task.result).to receive(:throw!)
      task.throw!(other_result)
      expect(task.result).to have_received(:throw!).with(other_result)
    end
  end

  describe "#execute" do
    context "with raise: false" do
      it "delegates to Worker.execute with raise: false" do
        allow(CMDx::Worker).to receive(:execute)
        task.execute(raise: false)
        expect(CMDx::Worker).to have_received(:execute).with(task, raise: false)
      end

      it "returns execution result" do
        result = task.execute(raise: false)
        expect(result).to be_a(Logger)
      end
    end

    context "with raise: true" do
      it "delegates to Worker.execute with raise: true" do
        allow(CMDx::Worker).to receive(:execute)
        task.execute(raise: true)
        expect(CMDx::Worker).to have_received(:execute).with(task, raise: true)
      end
    end

    context "without raise parameter" do
      it "defaults to raise: false" do
        allow(CMDx::Worker).to receive(:execute)
        task.execute
        expect(CMDx::Worker).to have_received(:execute).with(task, raise: false)
      end
    end
  end

  describe "#work" do
    let(:plain_task_class) { create_task_class(name: "PlainTask") }
    let(:plain_task) { plain_task_class.new }

    it "raises UndefinedMethodError" do
      expect { plain_task.work }.to raise_error(
        CMDx::UndefinedMethodError,
        /undefined method PlainTask\d+#work/
      )
    end
  end

  describe "#logger" do
    context "when task class has logger setting" do
      let(:custom_logger) { Logger.new(StringIO.new) }

      before do
        task_class.settings[:logger] = custom_logger
      end

      it "returns the task class logger" do
        expect(task.logger).to eq(custom_logger)
      end
    end

    context "when task class has no logger setting" do
      it "returns the global configuration logger" do
        expect(task.logger).to eq(CMDx.configuration.logger)
      end
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      hash = task.to_h

      aggregate_failures do
        expect(hash[:index]).to eq(task.result.index)
        expect(hash[:chain_id]).to eq(task.chain.id)
        expect(hash[:type]).to eq("Task")
        expect(hash[:tags]).to eq(task.class.settings[:tags])
        expect(hash[:class]).to be_a(String)
        expect(hash[:class]).to start_with("TestTask")
        expect(hash[:id]).to eq(task.id)
      end
    end

    context "when task includes Workflow" do
      let(:workflow_class) do
        create_task_class(name: "TestWorkflow") do
          include CMDx::Workflow
        end
      end
      let(:workflow_task) { workflow_class.new }

      it "returns type as Workflow" do
        expect(workflow_task.to_h[:type]).to eq("Workflow")
      end
    end

    context "when task has tags" do
      let(:tagged_task_class) do
        create_task_class(name: "TaggedTask") do
          settings(tags: %i[important test])
        end
      end
      let(:tagged_task) { tagged_task_class.new }

      it "includes tags in hash" do
        expect(tagged_task.to_h[:tags]).to eq(%i[important test])
      end
    end
  end

  describe "#to_s" do
    it "returns formatted string representation" do
      result = task.to_s
      expect(result).to be_a(String)
      expect(result).to include(task.id)
    end

    it "delegates to Utils::Format.to_str" do
      allow(CMDx::Utils::Format).to receive(:to_str).and_call_original
      task.to_s
      expect(CMDx::Utils::Format).to have_received(:to_str)
    end
  end

  describe ".settings" do
    context "when called without options" do
      it "returns default settings" do
        settings = task_class.settings

        aggregate_failures do
          expect(settings).to include(:attributes, :deprecate, :tags)
          expect(settings[:attributes]).to be_a(CMDx::AttributeRegistry)
          expect(settings[:deprecate]).to be false
          expect(settings[:tags]).to eq([])
        end
      end

      it "excludes logger from global configuration" do
        settings = task_class.settings
        expect(settings).not_to have_key(:logger)
      end
    end

    context "when called with options" do
      it "merges options with defaults" do
        settings = task_class.settings(custom: "value", tags: [:test])

        aggregate_failures do
          expect(settings[:custom]).to eq("value")
          expect(settings[:tags]).to eq([:test])
        end
      end
    end

    context "with superclass that responds to configuration" do
      let(:parent_class) do
        Class.new(CMDx::Task) do
          def self.configuration
            { parent_setting: "value" }
          end
        end
      end

      let(:child_class) do
        Class.new(parent_class)
      end

      it "inherits from superclass configuration" do
        allow(child_class).to receive(:superclass).and_return(parent_class)
        settings = child_class.settings
        expect(settings[:parent_setting]).to eq("value")
      end
    end
  end

  describe ".register" do
    let(:attribute) { CMDx::Attribute.new(:test_attr) }

    context "with :attribute type" do
      it "registers with attributes registry" do
        allow(task_class.settings[:attributes]).to receive(:register)
        task_class.register(:attribute, attribute, :option)
        expect(task_class.settings[:attributes]).to have_received(:register).with(attribute, :option)
      end
    end

    context "with :callback type" do
      it "registers with callbacks registry" do
        allow(task_class.settings[:callbacks]).to receive(:register)
        task_class.register(:callback, :before, :option)
        expect(task_class.settings[:callbacks]).to have_received(:register).with(:before, :option)
      end
    end

    context "with :coercion type" do
      it "registers with coercions registry" do
        allow(task_class.settings[:coercions]).to receive(:register)
        task_class.register(:coercion, :string, :option)
        expect(task_class.settings[:coercions]).to have_received(:register).with(:string, :option)
      end
    end

    context "with :middleware type" do
      it "registers with middlewares registry" do
        allow(task_class.settings[:middlewares]).to receive(:register)
        task_class.register(:middleware, :timeout, :option)
        expect(task_class.settings[:middlewares]).to have_received(:register).with(:timeout, :option)
      end
    end

    context "with :validator type" do
      it "registers with validators registry" do
        allow(task_class.settings[:validators]).to receive(:register)
        task_class.register(:validator, :presence, :option)
        expect(task_class.settings[:validators]).to have_received(:register).with(:presence, :option)
      end
    end

    context "with unknown type" do
      it "raises error" do
        expect { task_class.register(:unknown, :object) }.to raise_error(
          "unknown register type :unknown"
        )
      end
    end
  end

  describe ".attribute" do
    it "registers a single attribute" do
      allow(CMDx::Attribute).to receive(:define).and_call_original
      allow(task_class).to receive(:register)

      task_class.attribute(:name, type: :string)

      expect(CMDx::Attribute).to have_received(:define).with(:name, type: :string)
      expect(task_class).to have_received(:register).with(:attribute, kind_of(CMDx::Attribute))
    end
  end

  describe ".attributes" do
    it "registers multiple attributes" do
      allow(CMDx::Attribute).to receive(:defines).and_call_original
      allow(task_class).to receive(:register)

      task_class.attributes(:name, :age, type: :string)

      expect(CMDx::Attribute).to have_received(:defines).with(:name, :age, type: :string)
      expect(task_class).to have_received(:register).with(:attribute, kind_of(Array))
    end
  end

  describe ".optional" do
    it "registers optional attributes" do
      allow(CMDx::Attribute).to receive(:optional).and_call_original
      allow(task_class).to receive(:register)

      task_class.optional(:name, type: :string)

      expect(CMDx::Attribute).to have_received(:optional).with(:name, type: :string)
      expect(task_class).to have_received(:register).with(:attribute, kind_of(Array))
    end
  end

  describe ".required" do
    it "registers required attributes" do
      allow(CMDx::Attribute).to receive(:required).and_call_original
      allow(task_class).to receive(:register)

      task_class.required(:name, type: :string)

      expect(CMDx::Attribute).to have_received(:required).with(:name, type: :string)
      expect(task_class).to have_received(:register).with(:attribute, kind_of(Array))
    end
  end

  describe "callback methods" do
    CMDx::CallbackRegistry::TYPES.each do |callback_type|
      describe ".#{callback_type}" do
        it "registers #{callback_type} callback" do
          allow(task_class).to receive(:register)

          task_class.send(callback_type, :callable, option: :value)

          expect(task_class).to have_received(:register).with(:callback, callback_type, :callable, option: :value)
        end

        it "accepts block" do
          allow(task_class).to receive(:register)

          task_class.send(callback_type, option: :value) { :block }

          expect(task_class).to have_received(:register).with(:callback, callback_type, option: :value)
        end
      end
    end
  end

  describe ".execute" do
    it "creates new task and executes with raise: false" do
      result = task_class.execute(context_hash)

      aggregate_failures do
        expect(result).to be_a(CMDx::Result)
        expect(result.task.context.to_h).to include(context_hash)
        expect(result).to have_been_success
      end
    end

    it "does not raise on failure" do
      failing_class = create_failing_task(name: "FailingTask")
      result = failing_class.execute

      expect(result.failed?).to be true
    end
  end

  describe ".execute!" do
    it "creates new task and executes with raise: true" do
      result = task_class.execute!(context_hash)

      aggregate_failures do
        expect(result).to be_a(CMDx::Result)
        expect(result.task.context.to_h).to include(context_hash)
        expect(result).to have_been_success
      end
    end

    it "raises on failure" do
      failing_class = create_failing_task(name: "FailingTask")

      expect { failing_class.execute! }.to raise_error(CMDx::FailFault)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task, type: :unit do
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
        expect(task.dry_run?).to be(false)
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
    it "delegates success! to resolver" do
      expect(task.resolver).to receive(:success!).with("reason", metadata: "data")

      task.success!("reason", metadata: "data")
    end

    it "delegates skip! to resolver" do
      expect(task.resolver).to receive(:skip!).with("reason", metadata: "data")

      task.skip!("reason", metadata: "data")
    end

    it "delegates fail! to resolver" do
      expect(task.resolver).to receive(:fail!).with("reason", metadata: "data")

      task.fail!("reason", metadata: "data")
    end

    it "delegates throw! to resolver" do
      expect(task.resolver).to receive(:throw!).with("reason", metadata: "data")

      task.throw!("reason", metadata: "data")
    end
  end

  describe ".settings" do
    context "when called for the first time" do
      it "returns default settings with required keys" do
        settings = task_class.settings

        expect(settings).to be_a(CMDx::Settings)
        expect(settings.attributes).to be_a(CMDx::AttributeRegistry)
        expect(settings.tags).to eq([])
      end
    end

    context "when superclass has settings" do
      let(:parent_class) { create_task_class(name: "ParentTask") }
      let(:child_class) { Class.new(parent_class) }

      before do
        parent_class.settings(deprecate: true)
      end

      it "inherits from superclass settings" do
        child_settings = child_class.settings

        expect(child_settings.deprecate).to be(true)
      end

      it "can override inherited settings" do
        child_settings = child_class.settings(deprecate: false)

        expect(child_settings.deprecate).to be(false)
      end
    end

    context "with custom options" do
      it "merges custom options with defaults" do
        settings = task_class.settings(deprecate: :warn, tags: ["tag1"])

        expect(settings.deprecate).to eq(:warn)
        expect(settings.tags).to eq(["tag1"])
      end
    end

    it "memoizes settings" do
      settings1 = task_class.settings
      settings2 = task_class.settings

      expect(settings1).to be(settings2)
    end
  end

  describe ".register" do
    let(:mock_registry) { instance_double("MockRegistry") }

    before do
      allow(task_class.settings).to receive_messages(
        attributes: mock_registry,
        callbacks: mock_registry,
        coercions: mock_registry,
        middlewares: mock_registry,
        validators: mock_registry
      )
    end

    context "with :attribute type" do
      it "registers with attribute registry and defines readers" do
        expect(mock_registry).to receive(:register).with("object")
        expect(mock_registry).to receive(:define_readers_on!).with(task_class, ["object"])

        task_class.register(:attribute, "object")
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
        expect { task_class.register(:unknown, "object") }.to raise_error("unknown registry type :unknown")
      end
    end
  end

  describe ".attributes" do
    it "defines and registers multiple attributes" do
      mock_attributes = instance_double(CMDx::Attribute)
      expect(CMDx::Attribute).to receive(:build).with("arg1", "arg2").and_return(mock_attributes)
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

  describe ".remove_attributes" do
    it "removes multiple attributes from the registry" do
      mock_registry = instance_double(CMDx::AttributeRegistry)
      allow(task_class.settings).to receive(:attributes).and_return(mock_registry)

      expect(mock_registry).to receive(:undefine_readers_on!).with(task_class, %w[attr1 attr2 attr3])
      expect(mock_registry).to receive(:deregister).with(%w[attr1 attr2 attr3])

      task_class.remove_attributes("attr1", "attr2", "attr3")
    end

    it "handles single attribute removal" do
      mock_registry = instance_double(CMDx::AttributeRegistry)
      allow(task_class.settings).to receive(:attributes).and_return(mock_registry)

      expect(mock_registry).to receive(:undefine_readers_on!).with(task_class, ["single_attr"])
      expect(mock_registry).to receive(:deregister).with(["single_attr"])

      task_class.remove_attributes("single_attr")
    end
  end

  describe ".attributes_schema" do
    let(:task_with_attrs) do
      Class.new(CMDx::Task) do
        required :user_id, type: :integer
        optional :email, type: :string, default: "test@example.com"
        optional :profile, type: :hash do
          optional :bio, type: :string
          required :name, type: :string
        end

        def work; end
      end
    end

    it "returns a hash keyed by attribute method names" do
      schema = task_with_attrs.attributes_schema

      expect(schema).to be_a(Hash)
      expect(schema.keys).to contain_exactly(:user_id, :email, :profile)
    end

    it "includes attribute metadata from to_h" do
      schema = task_with_attrs.attributes_schema

      expect(schema[:user_id]).to include(
        name: :user_id,
        method_name: :user_id,
        required: true,
        types: [:integer]
      )

      expect(schema[:email]).to include(
        name: :email,
        method_name: :email,
        required: false,
        types: [:string]
      )
      expect(schema[:email][:options]).to include(default: "test@example.com")
    end

    it "includes nested children" do
      schema = task_with_attrs.attributes_schema

      expect(schema[:profile][:children]).to be_an(Array)
      expect(schema[:profile][:children].size).to eq(2)

      child_names = schema[:profile][:children].map { |c| c[:name] }
      expect(child_names).to contain_exactly(:bio, :name)
    end

    it "returns empty hash when no attributes defined" do
      empty_task = Class.new(CMDx::Task) { def work; end }

      expect(empty_task.attributes_schema).to eq({})
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

  describe "#dry_run?" do
    it "returns false by default" do
      expect(task.dry_run?).to be(false)
    end

    context "when initialized with dry_run: true" do
      let(:task) { task_class.new(dry_run: true) }

      it "returns true" do
        expect(task.dry_run?).to be(true)
      end
    end

    context "when executed with dry_run: true" do
      let(:dry_run_class) do
        create_task_class do
          def work; end
        end
      end

      it "returns true via execute" do
        result = dry_run_class.execute(dry_run: true)

        expect(result).to be_dry_run
      end

      it "returns true via execute!" do
        result = dry_run_class.execute!(dry_run: true)

        expect(result).to be_dry_run
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
      it "delegates to Executor.execute with raise: false" do
        expect(CMDx::Executor).to receive(:execute).with(task, raise: false)

        task.execute(raise: false)
      end
    end

    context "with raise: true" do
      it "delegates to Executor.execute with raise: true" do
        expect(CMDx::Executor).to receive(:execute).with(task, raise: true)

        task.execute(raise: true)
      end
    end

    context "with no arguments" do
      it "defaults to raise: false" do
        expect(CMDx::Executor).to receive(:execute).with(task, raise: false)

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
      let(:class_logger) { Logger.new(IO::NULL) }

      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(logger: class_logger))
      end

      it "returns the class logger" do
        expect(task.logger).to equal(class_logger)
      end
    end

    context "when class settings has no logger" do
      let(:config_logger) { Logger.new(IO::NULL) }

      before do
        allow(task.class).to receive(:settings).and_return(mock_settings)
        allow(CMDx.configuration).to receive(:logger).and_return(config_logger)
      end

      it "returns the configuration logger" do
        expect(task.logger).to equal(config_logger)
      end
    end

    context "when log_level is customized" do
      let(:shared_logger) { Logger.new(IO::NULL).tap { |l| l.level = Logger::INFO } }

      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(logger: shared_logger, log_level: Logger::DEBUG))
      end

      it "does not mutate the shared logger" do
        task.logger
        expect(shared_logger.level).to eq(Logger::INFO)
      end

      it "returns a different logger instance" do
        expect(task.logger).not_to equal(shared_logger)
        expect(task.logger.level).to eq(Logger::DEBUG)
      end
    end

    context "when log_formatter is customized" do
      let(:shared_logger) { Logger.new(IO::NULL) }
      let(:original_formatter) { shared_logger.formatter }
      let(:custom_formatter) { proc { |_s, _d, _p, msg| "#{msg}\n" } }

      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(logger: shared_logger, log_formatter: custom_formatter))
      end

      it "does not mutate the shared logger" do
        task.logger
        expect(shared_logger.formatter).to eq(original_formatter)
      end

      it "returns a different logger instance" do
        expect(task.logger).not_to equal(shared_logger)
        expect(task.logger.formatter).to eq(custom_formatter)
      end
    end
  end

  describe "#to_h" do
    let(:workflow_class) { Class.new(task_class) { include CMDx::Workflow } }
    let(:workflow_task) { workflow_class.new }

    before do
      allow(task.result).to receive(:index).and_return(5)
      allow(task.chain).to receive(:id).and_return("chain-123")
      allow(task.class).to receive(:settings).and_return(mock_settings(tags: %w[tag1 tag2]))
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
        expect(result_hash[:dry_run]).to be(false)
        expect(result_hash[:id]).to eq(task.id)
        expect(result_hash).not_to have_key(:context)
      end
    end

    context "when dump_context is enabled globally" do
      let(:task) { task_class.new(foo: "bar") }

      before do
        allow(task.result).to receive(:index).and_return(5)
        allow(task.chain).to receive(:id).and_return("chain-123")
        CMDx.configuration.dump_context = true
      end

      after { CMDx.configuration.dump_context = false }

      it "includes context in hash" do
        expect(task.to_h[:context]).to eq(foo: "bar")
      end
    end

    context "when dump_context is enabled via task settings" do
      let(:ctx_task_class) do
        create_task_class(name: "CtxTask") do
          settings dump_context: true
        end
      end
      let(:task) { ctx_task_class.new(baz: 42) }

      before do
        allow(task.result).to receive(:index).and_return(0)
        allow(task.chain).to receive(:id).and_return("chain-456")
        allow(task.class).to receive(:settings).and_return(
          mock_settings(tags: [], dump_context: true)
        )
      end

      it "includes context in hash" do
        expect(task.to_h[:context]).to eq(baz: 42)
      end
    end

    context "when task is workflow task" do
      before do
        allow(workflow_task.result).to receive(:index).and_return(3)
        allow(workflow_task.chain).to receive(:id).and_return("workflow-chain-456")
        allow(workflow_task.class).to receive(:settings).and_return(mock_settings(tags: ["workflow"]))
      end

      it "returns hash with type 'Workflow'" do
        result_hash = workflow_task.to_h

        expect(result_hash[:index]).to eq(3)
        expect(result_hash[:chain_id]).to eq("workflow-chain-456")
        expect(result_hash[:type]).to eq("Workflow")
        expect(result_hash[:tags]).to eq(["workflow"])
        expect(result_hash[:class]).to be_a(String)
        expect(result_hash[:class]).to match(/TestTask\d+/)
        expect(result_hash[:dry_run]).to be(false)
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

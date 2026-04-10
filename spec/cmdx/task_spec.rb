# frozen_string_literal: true

RSpec.describe CMDx::Task do
  describe "class methods" do
    it "raises UndefinedMethodError when work is not defined" do
      task = Class.new(described_class) { def self.name = "EmptyTask" }
      result = task.execute
      expect(result).to be_failed
      expect(result.cause).to be_a(CMDx::UndefinedMethodError)
    end

    it "has .definition" do
      task = Class.new(described_class) do
        def self.name = "DefnTask"

        def work; end
      end
      expect(task.definition).to be_a(CMDx::Definition)
    end

    it "has .task_type" do
      task = Class.new(described_class) do
        def self.name = "MyApp::CreateUser"

        def work; end
      end
      expect(task.task_type).to eq("my_app/create_user")
    end
  end

  describe "inheritance" do
    let(:parent) do
      Class.new(described_class) do
        def self.name = "ParentTask"
        required :name, :string
        def work; end
      end
    end

    let(:child) do
      Class.new(parent) do
        def self.name = "ChildTask"
        required :email, :string
      end
    end

    it "inherits parent attributes" do
      defn = child.definition
      names = defn.attributes.map(&:name)
      expect(names).to contain_exactly(:name, :email)
    end

    it "does not pollute parent" do
      child.definition
      expect(parent.definition.attributes.map(&:name)).to eq([:name])
    end
  end

  describe ".register" do
    it "registers middleware" do
      mw = Module.new { def self.call(_env, **) = yield }
      task = Class.new(described_class) do
        def self.name = "MWTask"
        register :middleware, mw, timeout: 5
        def work; end
      end
      defn = task.definition
      expect(defn.middleware.any? { |m, _| m == mw }).to be true
    end

    it "raises on unknown type" do
      expect do
        Class.new(described_class) { register :unknown, :foo }
      end.to raise_error(ArgumentError, /unknown/)
    end
  end

  describe ".settings" do
    it "configures tags" do
      task = Class.new(described_class) do
        def self.name = "TagTask"
        settings tags: %w[billing critical]
        def work; end
      end
      expect(task.definition.tags).to eq(%w[billing critical])
    end

    it "configures retry policy" do
      task = Class.new(described_class) do
        def self.name = "RetryTask"
        settings retries: { count: 3, retry_on: [StandardError], delay: 0 }
        def work; end
      end
      expect(task.definition.retry_policy.max_retries).to eq(3)
    end
  end
end

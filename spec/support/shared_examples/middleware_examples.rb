# frozen_string_literal: true

RSpec.shared_examples "a middleware" do
  it "can be instantiated" do
    expect { described_class.new }.not_to raise_error
  end

  it "implements the call method" do
    middleware = described_class.new
    expect(middleware).to respond_to(:call).with(2).arguments
  end
end

RSpec.shared_examples "middleware execution" do |execution_order|
  it "executes middleware in correct order" do
    result = subject

    expect(task.context.middleware_calls).to eq(execution_order)
    expect(result).to be_a(CMDx::Result)
  end
end

RSpec.shared_context "with middleware chain behavior" do
  let(:task_class) do
    Class.new(CMDx::Task) do
      def call
        context.middleware_calls ||= []
        context.middleware_calls << "task_executed"
      end
    end
  end

  let(:middleware_class) do
    Class.new(CMDx::Middleware) do
      def initialize(name) # rubocop:disable Lint/MissingSuper
        @name = name
      end

      def call(task, callable)
        task.context.middleware_calls ||= []
        task.context.middleware_calls << "#{@name}_before"

        result = callable.call(task)

        task.context.middleware_calls << "#{@name}_after"
        result
      end
    end
  end

  let(:task) { task_class.send(:new, {}) }
end

RSpec.shared_examples "short-circuiting middleware" do
  let(:short_circuit_middleware) do
    Class.new(CMDx::Middleware) do
      def call(task, _callable)
        task.context.middleware_calls ||= []
        task.context.middleware_calls << "short_circuit"

        begin
          task.skip!(reason: "Short circuited")
        rescue CMDx::Skipped
          # Catch the exception and return the result directly
        end
        task.result
      end
    end
  end

  it "prevents subsequent middleware and task execution" do
    result = subject

    expect(task.context.middleware_calls).to include("short_circuit")
    expect(result.skipped?).to be true
  end
end

RSpec.shared_examples "proc middleware" do
  let(:proc_middleware) do
    proc do |task, callable|
      task.context.middleware_calls ||= []
      task.context.middleware_calls << "proc_before"

      result = callable.call(task)

      task.context.middleware_calls << "proc_after"
      result
    end
  end

  it "executes proc middleware correctly" do
    result = subject

    expect(task.context.middleware_calls).to include("proc_before", "proc_after")
    expect(result).to be_a(CMDx::Result)
  end
end

RSpec.shared_examples "error propagation in middleware" do
  let(:error_middleware) do
    Class.new(CMDx::Middleware) do
      def call(_task, _callable)
        raise StandardError, "Middleware error"
      end
    end
  end

  it "allows errors to bubble up from middleware" do
    expect { subject }.to raise_error(StandardError, "Middleware error")
  end
end

RSpec.shared_examples "middleware registry operations" do
  describe "registry manipulation" do
    it "starts empty" do
      expect(registry.empty?).to be true
      expect(registry.size).to eq 0
    end

    it "adds middleware and updates size" do
      registry.use(middleware_class, "test")

      expect(registry.empty?).to be false
      expect(registry.size).to eq 1
    end

    it "supports method chaining" do
      result = registry.use(middleware_class, "test")
      expect(result).to be registry
    end
  end

  describe "duplication" do
    before { registry.use(middleware_class, "test") }

    it "creates independent copy" do
      copy = registry.dup

      expect(copy).not_to be registry
      expect(copy.size).to eq registry.size
    end

    it "doesn't share registry array" do
      copy = registry.dup
      copy.use(middleware_class, "new")

      expect(copy.size).to eq 2
      expect(registry.size).to eq 1
    end
  end
end

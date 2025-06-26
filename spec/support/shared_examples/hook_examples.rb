# frozen_string_literal: true

RSpec.shared_examples "a hook" do
  it "can be instantiated" do
    expect { described_class.new }.not_to raise_error
  end

  it "implements the call method" do
    hook = described_class.new
    expect(hook).to respond_to(:call).with(2).arguments
  end
end

RSpec.shared_examples "task hooks execution" do |expected_hooks|
  it "executes hooks in correct order" do
    expect(result.context.hooks).to eq(expected_hooks)
  end
end

RSpec.shared_examples "hook execution" do |execution_order|
  it "executes hooks in correct order" do
    subject

    expect(task.context.hook_calls).to eq(execution_order)
  end
end

RSpec.shared_context "with hook execution behavior" do
  let(:task_class) do
    Class.new(CMDx::Task) do
      def call
        context.hook_calls ||= []
        context.hook_calls << "task_executed"
      end
    end
  end

  let(:hook_class) do
    Class.new(CMDx::Hook) do
      def initialize(name) # rubocop:disable Lint/MissingSuper
        @name = name
      end

      def call(task, hook_type)
        task.context.hook_calls ||= []
        task.context.hook_calls << "#{@name}_#{hook_type}"
      end
    end
  end

  let(:task) { task_class.send(:new, {}) }
end

RSpec.shared_examples "conditional hook execution" do
  let(:conditional_hook) do
    Class.new(CMDx::Hook) do
      def initialize(condition) # rubocop:disable Lint/MissingSuper
        @condition = condition
      end

      def call(task, hook_type)
        return unless @condition.call(task, hook_type)

        task.context.hook_calls ||= []
        task.context.hook_calls << "conditional_executed"
      end
    end
  end

  it "executes when condition is true" do
    condition = ->(_task, hook_type) { hook_type == :on_success }
    hook = conditional_hook.new(condition)

    hook.call(task, :on_success)
    expect(task.context.hook_calls).to include("conditional_executed")
  end

  it "skips execution when condition is false" do
    condition = ->(_task, hook_type) { hook_type == :on_success }
    hook = conditional_hook.new(condition)

    hook.call(task, :on_failure)
    expect(task.context.hook_calls).to be_nil
  end
end

RSpec.shared_examples "error propagation in hooks" do
  let(:error_hook) do
    Class.new(CMDx::Hook) do
      def call(_task, _hook_type)
        raise StandardError, "Hook error"
      end
    end
  end

  it "allows errors to bubble up from hooks" do
    hook = error_hook.new
    expect { hook.call(task, :on_success) }.to raise_error(StandardError, "Hook error")
  end
end

RSpec.shared_examples "hook registry operations" do
  describe "registry manipulation" do
    it "starts empty" do
      expect(registry.empty?).to be true
      expect(registry.size).to eq 0
    end

    it "adds hooks and updates size" do
      registry.register(:before_execution, :test_method)

      expect(registry.empty?).to be false
      expect(registry.size).to eq 1
    end

    it "supports method chaining" do
      result = registry.register(:before_execution, :test_method)
      expect(result).to be registry
    end
  end

  describe "duplication" do
    before { registry.register(:before_execution, :test_method) }

    it "creates independent copy" do
      copy = registry.dup

      expect(copy).not_to be registry
      expect(copy.size).to eq registry.size
    end

    it "doesn't share registry hash" do
      copy = registry.dup
      copy.register(:on_success, :new_method)

      expect(copy.size).to eq 2
      expect(registry.size).to eq 1
    end
  end
end

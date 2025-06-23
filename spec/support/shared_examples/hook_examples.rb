# frozen_string_literal: true

RSpec.shared_examples "task hooks execution" do |expected_hooks|
  it "executes hooks in correct order" do
    expect(result.context.hooks).to eq(expected_hooks)
  end
end

RSpec.shared_examples "hook registration" do
  it "registers hooks correctly" do
    expect(task_class).to respond_to(:before_execution)
    expect(task_class).to respond_to(:after_execution)
    expect(task_class).to respond_to(:on_success)
    expect(task_class).to respond_to(:on_failed)
    expect(task_class).to respond_to(:on_skipped)
  end
end

RSpec.shared_examples "conditional hook execution" do
  it "executes hooks based on conditions" do
    expect(result.context.hooks).to include(*expected_executed_hooks)
    expect(result.context.hooks).not_to include(*expected_skipped_hooks)
  end
end

RSpec.shared_context "hook tracing" do
  let(:hook_tracer) do
    Class.new do
      def self.trace_hook(instance, method_name)
        (instance.ctx.hooks ||= []) << "#{instance.class.name || 'Unknown'}.#{method_name}"
      end
    end
  end

  def setup_hook_tracing(task_class)
    task_class.class_eval do
      private

      def trace_hook(method)
        HookTracer.trace_hook(self, method)
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::HookRegistry do
  include_context "with hook execution behavior"

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

  let(:registry) { described_class.new }

  describe "#initialize" do
    context "with no arguments" do
      it_behaves_like "hook registry operations"
    end

    context "with initial registry data" do
      it "can be initialized and populated manually" do
        registry[:before_execution] = [[:method_name, {}]]

        expect(registry.size).to eq 1
        expect(registry.empty?).to be false
        expect(registry.key?(:before_execution)).to be true
      end

      it "supports independent hash operations" do
        registry1 = described_class.new
        registry2 = described_class.new

        registry1[:before_execution] = [[:method1, {}]]
        registry2[:on_success] = [[:method2, {}]]

        expect(registry1.key?(:on_success)).to be false
        expect(registry2.key?(:before_execution)).to be false
        expect(registry1.size).to eq 1
        expect(registry2.size).to eq 1
      end
    end
  end

  describe "#register" do
    it_behaves_like "hook registry operations"

    context "with different hook types" do
      it "registers method name hook" do
        registry.register(:before_execution, :method_name)

        expect(registry.size).to eq 1
        expect(registry[:before_execution]).to eq([[[:method_name], {}]])
      end

      it "registers hook class instance" do
        hook = hook_class.new("test_hook")
        registry.register(:on_success, hook)

        expect(registry.size).to eq 1
        expect(registry[:on_success]).to be_an(Array)
      end

      it "registers proc hook" do
        proc_hook = proc { |task, _hook_type| task.context.proc_executed = true }
        registry.register(:after_execution, proc_hook)

        expect(registry.size).to eq 1
      end

      it "registers hook with conditions" do
        registry.register(:on_success, :method_name, if: :condition?)

        expect(registry[:on_success]).to eq([[[:method_name], { if: :condition? }]])
      end

      it "registers hook with block" do
        registry.register(:before_validation) { |task| task.context.block_executed = true }

        expect(registry.size).to eq 1
        expect(registry[:before_validation].first.first.first).to be_a(Proc)
      end

      it "registers multiple hooks for same event" do
        registry.register(:on_success, :method1, :method2)

        expect(registry[:on_success]).to eq([[%i[method1 method2], {}]])
      end
    end

    context "with method chaining" do
      it "returns self for method chaining" do
        result = registry.register(:before_execution, :method_name)
        expect(result).to be registry
      end

      it "supports chained registration" do
        registry
          .register(:before_execution, :before_method)
          .register(:on_success, :success_method)
          .register(:after_execution, :after_method)

        expect(registry.size).to eq 3
        expect(registry.keys).to contain_exactly(:before_execution, :on_success, :after_execution)
      end
    end

    context "with duplicate registrations" do
      it "prevents exact duplicates" do
        registry.register(:on_success, :method_name)
        registry.register(:on_success, :method_name)

        expect(registry[:on_success].size).to eq 1
      end

      it "allows different options for same method" do
        registry.register(:on_success, :method_name, if: :condition1?)
        registry.register(:on_success, :method_name, if: :condition2?)

        expect(registry[:on_success].size).to eq 2
      end
    end
  end

  describe "#call" do
    context "with no registered hooks" do
      it "returns without error" do
        expect { registry.call(task, :before_execution) }.not_to raise_error
      end

      it "doesn't modify task context" do
        original_context = task.context.to_h
        registry.call(task, :before_execution)

        expect(task.context.to_h).to eq original_context
      end
    end

    context "with unregistered hook type" do
      before { registry.register(:on_success, :success_method) }

      it "returns without executing any hooks" do
        registry.call(task, :before_execution)

        expect(task.context.hook_calls).to be_nil
      end
    end

    context "with single hook" do
      before { registry.register(:before_execution, hook_class.new("test")) }

      it "executes hook with correct parameters" do
        registry.call(task, :before_execution)

        expect(task.context.hook_calls).to eq(["test_before_execution"])
      end
    end

    context "with multiple hooks for same event" do
      before do
        registry.register(:on_success, hook_class.new("first"))
        registry.register(:on_success, hook_class.new("second"))
        registry.register(:on_success, hook_class.new("third"))
      end

      it "executes hooks in registration order" do
        registry.call(task, :on_success)

        expect(task.context.hook_calls).to eq(%w[
                                                first_on_success
                                                second_on_success
                                                third_on_success
                                              ])
      end
    end

    context "with method name hooks" do
      before do
        task.define_singleton_method(:test_method) do
          context.hook_calls ||= []
          context.hook_calls << "method_executed"
        end
      end

      it "executes method on task instance" do
        registry.register(:before_execution, :test_method)
        registry.call(task, :before_execution)

        expect(task.context.hook_calls).to include("method_executed")
      end
    end

    context "with proc hooks" do
      let(:proc_hook) do
        proc do
          context.hook_calls ||= []
          context.hook_calls << "proc_executed"
        end
      end

      before { registry.register(:on_complete, proc_hook) }

      it "executes proc on task instance" do
        registry.call(task, :on_complete)

        expect(task.context.hook_calls).to include("proc_executed")
      end
    end

    context "with hook class instances" do
      let(:hook_instance) { hook_class.new("instance") }

      before { registry.register(:after_execution, hook_instance) }

      it "calls hook instance with correct parameters" do
        registry.call(task, :after_execution)

        expect(task.context.hook_calls).to include("instance_after_execution")
      end
    end

    context "with mixed hook types" do
      let(:hook_instance) { hook_class.new("hook") }
      let(:proc_hook) { proc { |task, _| task.context.hook_calls << "proc_executed" } }

      before do
        task.define_singleton_method(:method_hook) do
          context.hook_calls ||= []
          context.hook_calls << "method_executed"
        end

        registry.register(:on_success, hook_instance)
        registry.register(:on_success, :method_hook)
        registry.register(:on_success, proc_hook)
      end

      it "executes all hook types correctly" do
        registry.call(task, :on_success)

        expect(task.context.hook_calls).to contain_exactly(
          "hook_on_success",
          "method_executed",
          "proc_executed"
        )
      end
    end

    context "with conditional hooks" do
      before do
        task.define_singleton_method(:should_execute?) { true }
        task.define_singleton_method(:should_not_execute?) { false }
      end

      context "with :if condition" do
        it "executes when condition is true" do
          registry.register(:on_success, hook_class.new("conditional"), if: :should_execute?)
          registry.call(task, :on_success)

          expect(task.context.hook_calls).to include("conditional_on_success")
        end

        it "skips when condition is false" do
          registry.register(:on_success, hook_class.new("conditional"), if: :should_not_execute?)
          registry.call(task, :on_success)

          expect(task.context.hook_calls).to be_nil
        end
      end

      context "with :unless condition" do
        it "executes when condition is false" do
          registry.register(:on_success, hook_class.new("conditional"), unless: :should_not_execute?)
          registry.call(task, :on_success)

          expect(task.context.hook_calls).to include("conditional_on_success")
        end

        it "skips when condition is true" do
          registry.register(:on_success, hook_class.new("conditional"), unless: :should_execute?)
          registry.call(task, :on_success)

          expect(task.context.hook_calls).to be_nil
        end
      end

      context "with combined conditions" do
        it "executes when both conditions are met" do
          registry.register(:on_success, hook_class.new("conditional"),
                            if: :should_execute?, unless: :should_not_execute?)
          registry.call(task, :on_success)

          expect(task.context.hook_calls).to include("conditional_on_success")
        end

        it "skips when :if condition fails" do
          registry.register(:on_success, hook_class.new("conditional"),
                            if: :should_not_execute?, unless: :should_not_execute?)
          registry.call(task, :on_success)

          expect(task.context.hook_calls).to be_nil
        end

        it "skips when :unless condition fails" do
          registry.register(:on_success, hook_class.new("conditional"),
                            if: :should_execute?, unless: :should_execute?)
          registry.call(task, :on_success)

          expect(task.context.hook_calls).to be_nil
        end
      end
    end

    context "with error handling" do
      let(:failing_hook) do
        Class.new(CMDx::Hook) do
          def call(_task, _hook_type)
            raise StandardError, "Hook execution failed"
          end
        end
      end

      it "allows hook errors to bubble up" do
        registry.register(:on_success, failing_hook.new)

        expect { registry.call(task, :on_success) }.to raise_error(StandardError, "Hook execution failed")
      end

      it "stops execution at first failing hook" do
        registry.register(:on_success, failing_hook.new)
        registry.register(:on_success, hook_class.new("after_error"))

        expect { registry.call(task, :on_success) }.to raise_error(StandardError)
        expect(task.context.hook_calls).to be_nil
      end
    end
  end

  describe "hash behavior" do
    it "behaves like a hash" do
      expect(registry).to respond_to(:[], :[]=, :keys, :values, :each, :empty?, :size)
    end

    it "allows direct hash access" do
      registry[:custom_hook] = [[:custom_method, {}]]

      expect(registry[:custom_hook]).not_to be_nil
      expect(registry.key?(:custom_hook)).to be true
    end

    it "supports enumeration" do
      registry.register(:before_execution, :method1)
      registry.register(:on_success, :method2)

      keys = []
      registry.each_key { |key| keys << key }

      expect(keys).to contain_exactly(:before_execution, :on_success)
    end
  end
end

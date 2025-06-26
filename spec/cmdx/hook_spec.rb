# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Hook do
  it_behaves_like "a hook"

  describe "#call" do
    subject(:hook) { described_class.new }

    context "when not overridden" do
      it "raises UndefinedCallError with descriptive message" do
        task = class_double("Task")
        hook_type = :before_execution

        expect { hook.call(task, hook_type) }.to raise_error(
          CMDx::UndefinedCallError, "call method not defined in CMDx::Hook"
        )
      end
    end
  end

  describe "custom hook implementation" do
    include_context "with hook execution behavior"

    let(:custom_hook_class) do
      Class.new(described_class) do
        def initialize(prefix = "") # rubocop:disable Lint/MissingSuper
          @prefix = prefix
        end

        def call(task, hook_type)
          task.context.hook_calls ||= []
          task.context.hook_calls << "#{@prefix}#{hook_type}"
        end
      end
    end

    context "with basic hook execution" do
      let(:hook) { custom_hook_class.new("test_") }

      it "executes hook with correct parameters" do
        hook.call(task, :before_execution)

        expect(task.context.hook_calls).to eq(["test_before_execution"])
      end

      it "receives task instance and hook type" do
        received_task = nil
        received_hook_type = nil

        hook_class = Class.new(described_class) do
          define_method :call do |task, hook_type|
            received_task = task
            received_hook_type = hook_type
          end
        end

        hook = hook_class.new
        hook.call(task, :on_success)

        expect(received_task).to be task
        expect(received_hook_type).to eq :on_success
      end
    end

    context "with hook that modifies task context" do
      let(:context_hook) do
        Class.new(described_class) do
          def call(task, hook_type)
            task.context.processed_by_hook = true
            task.context.hook_type_executed = hook_type
            task.context.hook_calls ||= []
            task.context.hook_calls << "context_modified"
          end
        end
      end

      it "allows hook to modify task context" do
        hook = context_hook.new
        hook.call(task, :before_validation)

        expect(task.context.processed_by_hook).to be true
        expect(task.context.hook_type_executed).to eq :before_validation
        expect(task.context.hook_calls).to include("context_modified")
      end
    end

    context "with hook that accesses task result" do
      let(:result_hook) do
        Class.new(described_class) do
          def call(task, hook_type)
            task.context.hook_calls ||= []
            task.context.hook_calls << "#{hook_type}_#{task.result.state}"
          end
        end
      end

      it "can access task result information" do
        task.result.executing!
        hook = result_hook.new
        hook.call(task, :on_executing)

        expect(task.context.hook_calls).to include("on_executing_executing")
      end
    end

    context "with conditional hook execution" do
      let(:conditional_hook) do
        Class.new(described_class) do
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

    context "with hook that handles errors" do
      let(:error_handling_hook) do
        Class.new(described_class) do
          def call(task, hook_type)
            task.context.hook_calls ||= []
            task.context.hook_calls << "error_handler_#{hook_type}"

            return unless hook_type == :on_failed && task.result.failed?

            task.context.error_handled = true
          end
        end
      end

      it "can handle and respond to task failures" do
        begin
          task.result.fail!
        rescue CMDx::Failed
          # Expected exception, continue with test
        end

        hook = error_handling_hook.new
        hook.call(task, :on_failed)

        expect(task.context.hook_calls).to include("error_handler_on_failed")
        expect(task.context.error_handled).to be true
      end
    end

    context "with multiple hook instances" do
      let(:hook_one) { custom_hook_class.new("first_") }
      let(:hook_two) { custom_hook_class.new("second_") }

      it "maintains independent state" do
        hook_one.call(task, :before_execution)
        hook_two.call(task, :before_execution)

        expect(task.context.hook_calls).to eq(
          %w[first_before_execution second_before_execution]
        )
      end
    end

    context "with hook inheritance" do
      let(:base_hook_class) do
        Class.new(described_class) do
          def call(task, hook_type)
            task.context.hook_calls ||= []
            task.context.hook_calls << "base_#{hook_type}"
            specific_behavior(task, hook_type)
          end

          def specific_behavior(_task, _hook_type)
            # To be overridden by subclasses
          end
        end
      end

      let(:specialized_hook_class) do
        Class.new(base_hook_class) do
          def specific_behavior(task, hook_type)
            task.context.hook_calls << "specialized_#{hook_type}"
          end
        end
      end

      it "supports hook class inheritance" do
        hook = specialized_hook_class.new
        hook.call(task, :on_success)

        expect(task.context.hook_calls).to eq(
          %w[base_on_success specialized_on_success]
        )
      end
    end
  end
end

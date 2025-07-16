# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Callback do
  subject(:callback) { described_class.new }

  describe ".call" do
    it "creates instance and delegates to instance call method" do
      task = instance_double("Task")
      allow_any_instance_of(described_class).to receive(:call).with(task, :before).and_return("delegated")

      result = described_class.call(task, :before)

      expect(result).to eq("delegated")
    end

    it "passes task and type to instance call method" do
      task = instance_double("Task")
      allow_any_instance_of(described_class).to receive(:call).with(task, :after).and_return("result")

      result = described_class.call(task, :after)

      expect(result).to eq("result")
    end
  end

  describe "#call" do
    it "raises UndefinedCallError with descriptive message" do
      task = instance_double("Task")

      expect { callback.call(task, :before) }.to raise_error(
        CMDx::UndefinedCallError,
        "call method not defined in CMDx::Callback"
      )
    end
  end

  describe "subclass implementation" do
    let(:working_callback_class) do
      Class.new(described_class) do
        def call(task, type)
          "executed_#{type}_for_#{task.class.name}"
        end
      end
    end

    let(:broken_callback_class) do
      Class.new(described_class) do
        # Intentionally doesn't implement call method
      end
    end

    it "works when subclass properly implements call method" do
      task = instance_double("Task", class: double(name: "TestTask"))

      result = working_callback_class.call(task, :before)

      expect(result).to eq("executed_before_for_TestTask")
    end

    it "raises error when subclass doesn't implement call method" do
      task = instance_double("Task")

      expect { broken_callback_class.call(task, :before) }.to raise_error(
        CMDx::UndefinedCallError,
        /call method not defined in/
      )
    end
  end

  describe "callback inheritance" do
    let(:parent_callback_class) do
      Class.new(described_class) do
        def call(_task, type)
          "executed_#{type}"
        end
      end
    end

    let(:child_callback_class) do
      parent_class = parent_callback_class
      Class.new(parent_class) do
        def call(task, type)
          "#{super}_with_child_behavior"
        end
      end
    end

    it "allows subclasses to extend parent behavior" do
      task = instance_double("Task")

      result = child_callback_class.call(task, :before)

      expect(result).to eq("executed_before_with_child_behavior")
    end
  end

  describe "integration with tasks" do
    describe "callback execution during task lifecycle" do
      it "executes callbacks for successful tasks" do
        executed_callbacks = []

        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            executed_callbacks << { type: :callback, task_status: task.result&.status }
          end
        end.new

        task_class = create_simple_task do
          on_executed callback_instance
        end

        result = task_class.call

        expect(result).to be_successful_task
        expect(executed_callbacks).to contain_exactly(
          { type: :callback, task_status: "success" }
        )
      end

      it "executes callbacks for failed tasks" do
        executed_callbacks = []

        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            executed_callbacks << { type: :callback, task_status: task.result&.status }
          end
        end.new

        task_class = create_failing_task(reason: "validation error") do
          on_failed callback_instance
        end

        result = task_class.call

        expect(result).to be_failed_task("validation error")
        expect(executed_callbacks).to contain_exactly(
          { type: :callback, task_status: "failed" }
        )
      end

      it "executes callbacks for skipped tasks" do
        executed_callbacks = []

        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            executed_callbacks << { type: :callback, task_status: task.result&.status }
          end
        end.new

        task_class = create_skipping_task(reason: "not needed") do
          on_skipped callback_instance
        end

        result = task_class.call

        expect(result).to be_skipped_task("not needed")
        expect(executed_callbacks).to contain_exactly(
          { type: :callback, task_status: "skipped" }
        )
      end
    end

    describe "callback types and timing" do
      it "executes lifecycle callbacks in correct order" do
        callback_order = []

        before_callback = Class.new(described_class) do
          define_method :call do |_task|
            callback_order << :before_execution
          end
        end.new

        after_callback = Class.new(described_class) do
          define_method :call do |_task|
            callback_order << :after_execution
          end
        end.new

        task_class = create_simple_task do
          before_execution before_callback
          after_execution after_callback
        end

        result = task_class.call

        expect(result).to be_successful_task
        expect(callback_order).to eq(%i[before_execution after_execution])
      end

      it "provides access to task context and result in callbacks" do
        context_data = nil
        result_metadata = nil

        callback = Class.new(described_class) do
          define_method :call do |task|
            context_data = task.context.to_h
            result_metadata = task.result.metadata
          end
        end.new

        task_class = create_simple_task do
          after_execution callback
        end

        result = task_class.call(user_id: 123)

        expect(result).to be_successful_task
        expect(context_data).to include(user_id: 123, executed: true)
        expect(result_metadata).to eq({})
      end
    end

    describe "callback integration with workflows" do
      it "executes callbacks for each task in workflow" do
        executed_tasks = []

        callback = Class.new(described_class) do
          define_method :call do |task|
            # Only track task callbacks, not workflow callbacks
            return if task.class.name.include?("Workflow")

            executed_tasks << task.class.name.split(/\d+/).first
          end
        end.new

        task1 = create_simple_task(name: "FirstTask") { on_executed callback }
        task2 = create_simple_task(name: "SecondTask") { on_executed callback }

        workflow_class = create_simple_workflow(tasks: [task1, task2])

        result = workflow_class.call

        expect(result).to be_successful_task
        expect(executed_tasks).to contain_exactly("FirstTask", "SecondTask")
      end

      it "handles mixed outcomes in workflows" do
        task_outcomes = []

        outcome_callback = Class.new(described_class) do
          define_method :call do |task|
            # Only track task callbacks, not workflow callbacks
            return if task.class.name.include?("Workflow")

            task_outcomes << task.result.status
          end
        end.new

        success_task = create_simple_task { on_executed outcome_callback }
        skip_task = create_skipping_task { on_executed outcome_callback }

        workflow_class = create_workflow_class do
          cmd_settings!(workflow_halt: [])
          process success_task
          process skip_task
        end

        result = workflow_class.call

        expect(result).to be_executed
        expect(task_outcomes).to contain_exactly("success", "skipped")
      end
    end
  end
end

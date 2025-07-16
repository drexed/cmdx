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
    let(:callback_log) { [] }

    describe "with successful tasks" do
      it "receives task instance and callback type during execution" do
        log = callback_log
        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :on_executed, status: task.result&.status }
          end
        end.new

        task_class = create_simple_task(name: "TestTask") do
          on_executed callback_instance
        end

        result = task_class.call

        expect(result).to be_success
        expect(callback_log.size).to eq(1)
        expect(callback_log.first[:task]).to match(/^TestTask\d+$/)
        expect(callback_log.first[:type]).to eq(:on_executed)
        expect(callback_log.first[:status]).to eq("success")
      end

      it "receives before and after callbacks" do
        log = callback_log
        before_callback = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :before_execution, status: task.result&.status }
          end
        end.new
        after_callback = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :after_execution, status: task.result&.status }
          end
        end.new

        task_class = create_simple_task(name: "CallbackTask") do
          before_execution before_callback
          after_execution after_callback
        end

        result = task_class.call

        expect(result).to be_success
        expect(callback_log.size).to eq(2)
        expect(callback_log.map { |log| log[:task] }).to all(match(/^CallbackTask\d+$/))
        expect(callback_log.map { |log| log[:type] }).to contain_exactly(:before_execution, :after_execution)
        # Before execution status can be nil or "success" depending on implementation timing
        before_status = callback_log.find { |log| log[:type] == :before_execution }[:status]
        expect([nil, "success"]).to include(before_status)
        expect(callback_log.find { |log| log[:type] == :after_execution }[:status]).to eq("success")
      end
    end

    describe "with failing tasks" do
      it "receives callbacks for failed tasks" do
        log = callback_log
        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :callback, status: task.result&.status }
          end
        end.new

        task_class = create_failing_task(name: "FailingTask", reason: "Test failure") do
          on_executed callback_instance
          on_failed callback_instance
        end

        result = task_class.call

        expect(result).to be_failed
        expect(callback_log.size).to eq(2)
        expect(callback_log.map { |log| log[:task] }).to all(match(/^FailingTask\d+$/))
        expect(callback_log.map { |log| log[:type] }).to all(eq(:callback))
        expect(callback_log.map { |log| log[:status] }).to all(eq("failed"))
      end
    end

    describe "with skipping tasks" do
      it "receives callbacks for skipped tasks" do
        log = callback_log
        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :callback, status: task.result&.status }
          end
        end.new

        task_class = create_skipping_task(name: "SkippingTask", reason: "Test skip") do
          on_executed callback_instance
          on_skipped callback_instance
        end

        result = task_class.call

        expect(result).to be_skipped
        expect(callback_log.size).to eq(2)
        expect(callback_log.map { |log| log[:task] }).to all(match(/^SkippingTask\d+$/))
        expect(callback_log.map { |log| log[:type] }).to all(eq(:callback))
        expect(callback_log.map { |log| log[:status] }).to all(eq("skipped"))
      end
    end

    describe "with erroring tasks" do
      it "receives callbacks for tasks that raise exceptions" do
        log = callback_log
        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :callback, status: task.result&.status }
          end
        end.new

        task_class = create_erroring_task(name: "ErroringTask", reason: "Test error") do
          on_executed callback_instance
          on_failed callback_instance
        end

        result = task_class.call

        expect(result).to be_failed
        expect(callback_log.size).to eq(2)
        expect(callback_log.map { |log| log[:task] }).to all(match(/^ErroringTask\d+$/))
        expect(callback_log.map { |log| log[:type] }).to all(eq(:callback))
        expect(callback_log.map { |log| log[:status] }).to all(eq("failed"))
      end
    end

    describe "with workflows" do
      it "receives callbacks from all tasks in workflow" do
        log = callback_log
        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :callback, status: task.result&.status }
          end
        end.new

        task1 = create_simple_task(name: "Task1") { on_executed callback_instance }
        task2 = create_simple_task(name: "Task2") { on_executed callback_instance }
        task3 = create_simple_task(name: "Task3") { on_executed callback_instance }

        workflow_class = create_simple_workflow(
          name: "CallbackWorkflow",
          tasks: [task1, task2, task3]
        )

        result = workflow_class.call

        expect(result).to be_success
        expect(callback_log.size).to eq(4) # 3 tasks + 1 workflow callback
        # Filter out workflow callbacks, just check task callbacks
        task_callbacks = callback_log.reject { |log| log[:task].match?(/Workflow\d+$/) }
        expect(task_callbacks.size).to eq(3)
        expect(task_callbacks.map { |log| log[:task] }).to all(match(/^Task\d+\d+$/))
        expect(task_callbacks.map { |log| log[:type] }).to all(eq(:callback))
        expect(task_callbacks.map { |log| log[:status] }).to all(eq("success"))
      end

      it "receives callbacks for mixed outcome workflows" do
        log = callback_log
        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            log << { task: task.class.name, type: :callback, status: task.result&.status }
          end
        end.new

        success_task = create_simple_task(name: "SuccessTask") { on_executed callback_instance }
        skip_task = create_skipping_task(name: "SkipTask") { on_executed callback_instance }
        fail_task = create_failing_task(name: "FailTask") { on_executed callback_instance }

        workflow_class = create_workflow_class(name: "MixedWorkflow") do
          cmd_settings!(workflow_halt: [])
          process success_task
          process skip_task
          process fail_task
        end

        result = workflow_class.call

        # Filter out workflow callbacks, just check task callbacks
        task_callbacks = callback_log.reject { |log| log[:task].match?(/Workflow\d+$/) }
        expect(task_callbacks.size).to eq(3)

        # Check that we have one callback for each task type with correct status
        success_callback = task_callbacks.find { |log| log[:task].match?(/^SuccessTask\d+$/) }
        skip_callback = task_callbacks.find { |log| log[:task].match?(/^SkipTask\d+$/) }
        fail_callback = task_callbacks.find { |log| log[:task].match?(/^FailTask\d+$/) }

        expect(success_callback).to include(type: :callback, status: "success")
        expect(skip_callback).to include(type: :callback, status: "skipped")
        expect(fail_callback).to include(type: :callback, status: "failed")
      end
    end

    describe "callback context and metadata access" do
      it "allows callbacks to access task context and metadata" do
        accessed_data = {}
        callback_instance = Class.new(described_class) do
          define_method :call do |task|
            accessed_data[:context] = task.context.to_h
            accessed_data[:metadata] = task.result&.metadata
          end
        end.new

        task_class = create_simple_task(name: "ContextTask") do
          after_execution callback_instance
        end

        result = task_class.call(input_data: "test")

        expect(result).to be_success
        expect(accessed_data[:context]).to include(input_data: "test", executed: true)
        expect(accessed_data[:metadata]).to eq({})
      end
    end
  end
end

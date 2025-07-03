# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Workflow do
  describe ".workflow_groups" do
    it "returns an empty array when no groups are defined" do
      workflow_class = create_workflow_class

      expect(workflow_class.workflow_groups).to eq([])
    end

    it "returns array of defined groups" do
      task_a = create_task_class(name: "TaskA")
      task_b = create_task_class(name: "TaskB")
      workflow_class = create_workflow_class(name: "TestWorkflow") do
        process task_a
        process task_b
      end

      groups = workflow_class.workflow_groups

      expect(groups.size).to eq(2)
      expect(groups.first.tasks).to eq([task_a])
      expect(groups.first.options).to eq({})
    end

    it "preserves task declaration order" do
      task_a = create_task_class(name: "TaskA")
      task_b = create_task_class(name: "TaskB")
      task_c = create_task_class(name: "TaskC")
      workflow_class = create_workflow_class(name: "OrderTestWorkflow") do
        process task_c
        process task_a
        process task_b
      end

      groups = workflow_class.workflow_groups
      tasks = groups.map(&:tasks).flatten

      expect(tasks).to eq([task_c, task_a, task_b])
    end

    it "maintains groups across multiple process calls" do
      task_a = create_task_class(name: "TaskA")
      task_b = create_task_class(name: "TaskB")
      task_c = create_task_class(name: "TaskC")
      workflow_class = create_workflow_class(name: "MultiProcessWorkflow")

      workflow_class.process task_a
      workflow_class.process task_b, task_c

      groups = workflow_class.workflow_groups
      expect(groups.size).to eq(2)
      expect(groups.first.tasks).to eq([task_a])
      expect(groups.last.tasks).to eq([task_b, task_c])
    end

    it "inherits empty groups from parent class" do
      parent_workflow = create_workflow_class(name: "ParentWorkflow")
      child_workflow = Class.new(parent_workflow)

      expect(child_workflow.workflow_groups).to eq([])
    end

    it "does not share groups between different workflow classes" do
      task_a = create_task_class(name: "TaskA")
      task_b = create_task_class(name: "TaskB")
      workflow_class_one = create_workflow_class(name: "WorkflowOne")
      workflow_class_two = create_workflow_class(name: "WorkflowTwo")

      workflow_class_one.process task_a
      workflow_class_two.process task_b

      expect(workflow_class_one.workflow_groups.size).to eq(1)
      expect(workflow_class_two.workflow_groups.size).to eq(1)
      expect(workflow_class_one.workflow_groups.first.tasks).to eq([task_a])
      expect(workflow_class_two.workflow_groups.first.tasks).to eq([task_b])
    end
  end

  describe ".process" do
    let(:workflow_class) { create_workflow_class(name: "ProcessTestWorkflow") }
    let(:task_a) { create_task_class(name: "TaskA") }
    let(:task_b) { create_task_class(name: "TaskB") }

    it "creates group with single task" do
      workflow_class.process task_a

      group = workflow_class.workflow_groups.first
      expect(group.tasks).to eq([task_a])
      expect(group.options).to eq({})
    end

    it "creates group with multiple tasks" do
      workflow_class.process task_a, task_b

      group = workflow_class.workflow_groups.first
      expect(group.tasks).to eq([task_a, task_b])
    end

    it "accepts options for group configuration" do
      workflow_class.process task_a, task_b, if: proc { true }, workflow_halt: ["failed"]

      group = workflow_class.workflow_groups.first
      expect(group.options[:if]).to be_a(Proc)
      expect(group.options[:workflow_halt]).to eq(["failed"])
    end

    it "handles flattened task arrays" do
      workflow_class.process [task_a, task_b]

      group = workflow_class.workflow_groups.first
      expect(group.tasks).to eq([task_a, task_b])
    end

    it "raises error for non-task classes" do
      expect do
        workflow_class.process String
      end.to raise_error(TypeError, "must be a Task or Workflow")
    end

    it "allows nested workflow classes" do
      nested_workflow = create_workflow_class(name: "NestedWorkflow")
      workflow_class.process nested_workflow

      group = workflow_class.workflow_groups.first
      expect(group.tasks).to eq([nested_workflow])
    end

    it "creates separate groups for multiple process calls" do
      workflow_class.process task_a
      workflow_class.process task_b

      expect(workflow_class.workflow_groups.size).to eq(2)
    end

    it "preserves order of task addition" do
      task_c = create_task_class(name: "TaskC")
      task_d = create_task_class(name: "TaskD")

      workflow_class.process task_a, task_b
      workflow_class.process task_c
      workflow_class.process task_d

      groups = workflow_class.workflow_groups
      expect(groups[0].tasks).to eq([task_a, task_b])
      expect(groups[1].tasks).to eq([task_c])
      expect(groups[2].tasks).to eq([task_d])
    end
  end

  describe "::Group" do
    let(:task_a) { create_task_class(name: "TaskA") }
    let(:task_b) { create_task_class(name: "TaskB") }

    describe "#initialize" do
      it "sets tasks and options" do
        options = { workflow_halt: [:failed] }
        group = described_class::Group.new([task_a, task_b], options)

        expect(group.tasks).to eq([task_a, task_b])
        expect(group.options).to eq(options)
      end

      it "handles empty options" do
        group = described_class::Group.new([task_a], {})

        expect(group.tasks).to eq([task_a])
        expect(group.options).to eq({})
      end
    end

    describe "#to_a" do
      it "returns array representation" do
        options = { workflow_halt: [:failed] }
        group = described_class::Group.new([task_a], options)

        expect(group.to_a).to eq([[task_a], options])
      end
    end
  end

  describe "#call" do
    let(:simple_task) { create_simple_task(name: "SimpleTask") }
    let(:failing_task) { create_failing_task(name: "FailingTask", reason: "Task failed") }

    context "when workflow has no groups" do
      let(:workflow_class) { create_workflow_class(name: "EmptyWorkflow") }

      it "returns successful result" do
        result = workflow_class.call(test: "data")

        expect(result).to be_a(CMDx::Result)
        expect(result.status).to eq("success")
      end
    end

    context "when all tasks succeed" do
      it "executes all tasks and returns success" do
        task = simple_task
        workflow_class = create_workflow_class(name: "SuccessfulWorkflow") do
          process task
        end

        result = workflow_class.call(test: "data")

        expect(result.status).to eq("success")
        expect(result.context.executed).to be(true)
      end
    end

    context "when task fails with default halt behavior" do
      it "stops execution on failure" do
        task = failing_task
        workflow_class = create_workflow_class(name: "FailingWorkflow") do
          process task
        end

        result = workflow_class.call(test: "data")

        expect(result.status).to eq("failed")
      end
    end

    context "when groups have custom halt behavior" do
      it "respects group-level workflow_halt setting" do
        task = failing_task
        workflow_class = create_workflow_class(name: "CustomHaltWorkflow") do
          process task, workflow_halt: []
        end

        result = workflow_class.call(test: "data")

        expect(result.status).to eq("success")
      end

      it "handles multiple halt statuses" do
        skipping_task = create_skipping_task(name: "SkippingTask", reason: "Skipping task")

        workflow_class = create_workflow_class(name: "MultiHaltWorkflow") do
          process skipping_task, workflow_halt: %w[failed skipped]
        end

        result = workflow_class.call(test: "data")

        expect(result.status).to eq("skipped")
      end
    end

    context "when using conditional execution" do
      it "evaluates if conditions" do
        task = simple_task
        workflow_class = create_workflow_class(name: "ConditionalIfWorkflow") do
          process task, if: proc { context.should_run }
        end

        result = workflow_class.call(should_run: true)
        expect(result.context.executed).to be(true)

        result = workflow_class.call(should_run: false)
        expect(result.context.executed).to be_nil
      end

      it "evaluates unless conditions" do
        task = simple_task
        workflow_class = create_workflow_class(name: "ConditionalUnlessWorkflow") do
          process task, unless: proc { context.should_skip }
        end

        result = workflow_class.call(should_skip: false)
        expect(result.context.executed).to be(true)

        result = workflow_class.call(should_skip: true)
        expect(result.context.executed).to be_nil
      end

      it "supports symbol method conditions" do
        task = simple_task
        workflow_class = create_workflow_class(name: "SymbolMethodWorkflow") do
          process task, if: :should_execute?

          private

          def should_execute?
            context.enabled
          end
        end

        result = workflow_class.call(enabled: true)
        expect(result.context.executed).to be(true)

        result = workflow_class.call(enabled: false)
        expect(result.context.executed).to be_nil
      end
    end

    context "when handling edge cases" do
      it "handles empty task arrays in groups" do
        workflow_class = create_workflow_class(name: "EmptyGroupWorkflow")
        workflow_class.instance_variable_set(:@workflow_groups, [described_class::Group.new([], {})])

        result = workflow_class.call(test: "data")

        expect(result.status).to eq("success")
      end

      it "handles groups with empty options" do
        task = simple_task
        workflow_class = create_workflow_class(name: "EmptyOptionsWorkflow") do
          process task
        end

        result = workflow_class.call(test: "data")

        expect(result.status).to eq("success")
        expect(result.context.executed).to be(true)
      end
    end
  end

  describe "integration scenarios" do
    let(:counter_task_one) do
      create_task_class(name: "CounterTaskOne") do
        def call
          context.counter ||= 0
          context.counter += 1
          context.executed_tasks ||= []
          context.executed_tasks << "counter_#{context.counter}"
        end
      end
    end

    let(:failing_task) do
      create_task_class(name: "FailingTask") do
        def call
          context.executed_tasks ||= []
          context.executed_tasks << "failing_task"
          fail!(reason: "Task failed")
        end
      end
    end

    it "executes simple workflow workflow" do
      task = counter_task_one
      workflow_class = create_workflow_class(name: "SimpleWorkflowWorkflow") do
        process task
        process task
      end

      result = workflow_class.call(test: "data")

      expect(result.status).to eq("success")
      expect(result.context.executed_tasks).to eq(%w[counter_1 counter_2])
    end

    it "stops execution on first failure with default halt behavior" do
      # Create separate counter task classes to avoid shared state
      counter_task_two = create_task_class(name: "CounterTaskTwo") do
        def call
          context.counter ||= 0
          context.counter += 1
          context.executed_tasks ||= []
          context.executed_tasks << "counter_#{context.counter}"
        end
      end

      task_one = counter_task_one
      task_two = counter_task_two
      failing = failing_task
      workflow_class = create_workflow_class(name: "FailureHaltWorkflow") do
        process task_one
        process failing
        process task_two
      end

      result = workflow_class.call(test: "data")

      expect(result.context.executed_tasks).to eq(%w[counter_1 failing_task])
      expect(result.status).to eq("failed")
    end

    it "continues execution with custom halt behavior" do
      counter = counter_task_one
      failing = failing_task
      workflow_class = create_workflow_class(name: "ContinueOnFailureWorkflow") do
        process counter
        process failing, workflow_halt: []
        process counter
      end

      result = workflow_class.call(test: "data")

      expect(result.context.executed_tasks).to eq(%w[counter_1 failing_task counter_2])
      expect(result.status).to eq("success")
    end

    it "handles conditional execution with context data" do
      counter = counter_task_one
      conditional_task = create_task_class(name: "ConditionalTask") do
        def call
          context.conditional_executed = true
        end
      end

      workflow_class = create_workflow_class(name: "ConditionalExecutionWorkflow") do
        process counter
        process conditional_task, if: proc { context.counter > 0 }
      end

      result = workflow_class.call(test: "data")

      expect(result.context.conditional_executed).to be(true)
      expect(result.status).to eq("success")
    end

    it "handles nested workflow execution" do
      counter = counter_task_one
      inner_workflow = create_workflow_class(name: "InnerWorkflow") do
        process counter
        process counter
      end

      outer_workflow = create_workflow_class(name: "OuterWorkflow") do
        process counter
        process inner_workflow
        process counter
      end

      result = outer_workflow.call(test: "data")

      expect(result.status).to eq("success")
      expect(result.context.counter).to eq(4)
    end

    it "preserves context across all tasks" do
      data_task = create_task_class(name: "DataTask") do
        def call
          context.shared_data ||= []
          context.shared_data << "task_#{object_id}"
        end
      end

      workflow_class = create_workflow_class(name: "ContextPreservationWorkflow") do
        process data_task
        process data_task
        process data_task
      end

      result = workflow_class.call(test: "data")

      expect(result.status).to eq("success")
      expect(result.context.shared_data.size).to eq(3)
      expect(result.context.shared_data.all? { |item| item.start_with?("task_") }).to be(true)
    end
  end
end

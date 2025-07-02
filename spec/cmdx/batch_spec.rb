# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Batch do
  describe ".batch_groups" do
    it "returns an empty array when no groups are defined" do
      batch_class = Class.new(described_class)

      expect(batch_class.batch_groups).to eq([])
    end

    it "returns array of defined groups" do
      task_a = Class.new(CMDx::Task)
      task_b = Class.new(CMDx::Task)
      batch_class = Class.new(described_class) do
        process task_a
        process task_b
      end

      groups = batch_class.batch_groups

      expect(groups.size).to eq(2)
      expect(groups.first.tasks).to eq([task_a])
      expect(groups.first.options).to eq({})
    end

    it "preserves task declaration order" do
      task_a = Class.new(CMDx::Task)
      task_b = Class.new(CMDx::Task)
      task_c = Class.new(CMDx::Task)
      batch_class = Class.new(described_class) do
        process task_c
        process task_a
        process task_b
      end

      groups = batch_class.batch_groups
      tasks = groups.map(&:tasks).flatten

      expect(tasks).to eq([task_c, task_a, task_b])
    end

    it "maintains groups across multiple process calls" do
      task_a = Class.new(CMDx::Task)
      task_b = Class.new(CMDx::Task)
      task_c = Class.new(CMDx::Task)
      batch_class = Class.new(described_class)

      batch_class.process task_a
      batch_class.process task_b, task_c

      groups = batch_class.batch_groups
      expect(groups.size).to eq(2)
      expect(groups.first.tasks).to eq([task_a])
      expect(groups.last.tasks).to eq([task_b, task_c])
    end

    it "inherits empty groups from parent class" do
      parent_batch = Class.new(described_class)
      child_batch = Class.new(parent_batch)

      expect(child_batch.batch_groups).to eq([])
    end

    it "does not share groups between different batch classes" do
      task_a = Class.new(CMDx::Task)
      task_b = Class.new(CMDx::Task)
      batch_class_one = Class.new(described_class)
      batch_class_two = Class.new(described_class)

      batch_class_one.process task_a
      batch_class_two.process task_b

      expect(batch_class_one.batch_groups.size).to eq(1)
      expect(batch_class_two.batch_groups.size).to eq(1)
      expect(batch_class_one.batch_groups.first.tasks).to eq([task_a])
      expect(batch_class_two.batch_groups.first.tasks).to eq([task_b])
    end
  end

  describe ".process" do
    let(:batch_class) { Class.new(described_class) }
    let(:task_a) { Class.new(CMDx::Task) }
    let(:task_b) { Class.new(CMDx::Task) }

    it "creates group with single task" do
      batch_class.process task_a

      group = batch_class.batch_groups.first
      expect(group.tasks).to eq([task_a])
      expect(group.options).to eq({})
    end

    it "creates group with multiple tasks" do
      batch_class.process task_a, task_b

      group = batch_class.batch_groups.first
      expect(group.tasks).to eq([task_a, task_b])
    end

    it "accepts options for group configuration" do
      batch_class.process task_a, task_b, if: proc { true }, batch_halt: ["failed"]

      group = batch_class.batch_groups.first
      expect(group.options[:if]).to be_a(Proc)
      expect(group.options[:batch_halt]).to eq(["failed"])
    end

    it "handles flattened task arrays" do
      batch_class.process [task_a, task_b]

      group = batch_class.batch_groups.first
      expect(group.tasks).to eq([task_a, task_b])
    end

    it "raises error for non-task classes" do
      expect do
        batch_class.process String
      end.to raise_error(TypeError, "must be a Task or Batch")
    end

    it "allows nested batch classes" do
      nested_batch = Class.new(described_class)
      batch_class.process nested_batch

      group = batch_class.batch_groups.first
      expect(group.tasks).to eq([nested_batch])
    end

    it "creates separate groups for multiple process calls" do
      batch_class.process task_a
      batch_class.process task_b

      expect(batch_class.batch_groups.size).to eq(2)
    end

    it "preserves order of task addition" do
      task_c = Class.new(CMDx::Task)
      task_d = Class.new(CMDx::Task)

      batch_class.process task_a, task_b
      batch_class.process task_c
      batch_class.process task_d

      groups = batch_class.batch_groups
      expect(groups[0].tasks).to eq([task_a, task_b])
      expect(groups[1].tasks).to eq([task_c])
      expect(groups[2].tasks).to eq([task_d])
    end
  end

  describe "::Group" do
    let(:task_a) { Class.new(CMDx::Task) }
    let(:task_b) { Class.new(CMDx::Task) }

    describe "#initialize" do
      it "sets tasks and options" do
        options = { batch_halt: [:failed] }
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
        options = { batch_halt: [:failed] }
        group = described_class::Group.new([task_a], options)

        expect(group.to_a).to eq([[task_a], options])
      end
    end
  end

  describe "#call" do
    let(:simple_task) do
      Class.new(CMDx::Task) do
        def call
          context.executed = true
        end
      end
    end

    let(:failing_task) do
      Class.new(CMDx::Task) do
        def call
          fail!(reason: "Task failed")
        end
      end
    end

    context "when batch has no groups" do
      let(:batch_class) { Class.new(described_class) }

      it "returns successful result" do
        result = batch_class.call(test: "data")

        expect(result).to be_a(CMDx::Result)
        expect(result.status).to eq("success")
      end
    end

    context "when all tasks succeed" do
      it "executes all tasks and returns success" do
        task = simple_task
        batch_class = Class.new(described_class) do
          process task
        end

        result = batch_class.call(test: "data")

        expect(result.status).to eq("success")
        expect(result.context.executed).to be(true)
      end
    end

    context "when task fails with default halt behavior" do
      it "stops execution on failure" do
        task = failing_task
        batch_class = Class.new(described_class) do
          process task
        end

        result = batch_class.call(test: "data")

        expect(result.status).to eq("failed")
      end
    end

    context "when groups have custom halt behavior" do
      it "respects group-level batch_halt setting" do
        task = failing_task
        batch_class = Class.new(described_class) do
          process task, batch_halt: []
        end

        result = batch_class.call(test: "data")

        expect(result.status).to eq("success")
      end

      it "handles multiple halt statuses" do
        skipping_task = Class.new(CMDx::Task) do
          def call
            skip!(reason: "Skipping task")
          end
        end

        batch_class = Class.new(described_class) do
          process skipping_task, batch_halt: %w[failed skipped]
        end

        result = batch_class.call(test: "data")

        expect(result.status).to eq("skipped")
      end
    end

    context "when using conditional execution" do
      it "evaluates if conditions" do
        task = simple_task
        batch_class = Class.new(described_class) do
          process task, if: proc { context.should_run }
        end

        result = batch_class.call(should_run: true)
        expect(result.context.executed).to be(true)

        result = batch_class.call(should_run: false)
        expect(result.context.executed).to be_nil
      end

      it "evaluates unless conditions" do
        task = simple_task
        batch_class = Class.new(described_class) do
          process task, unless: proc { context.should_skip }
        end

        result = batch_class.call(should_skip: false)
        expect(result.context.executed).to be(true)

        result = batch_class.call(should_skip: true)
        expect(result.context.executed).to be_nil
      end

      it "supports symbol method conditions" do
        task = simple_task
        batch_class = Class.new(described_class) do
          process task, if: :should_execute?

          private

          def should_execute?
            context.enabled
          end
        end

        result = batch_class.call(enabled: true)
        expect(result.context.executed).to be(true)

        result = batch_class.call(enabled: false)
        expect(result.context.executed).to be_nil
      end
    end

    context "when handling edge cases" do
      it "handles empty task arrays in groups" do
        batch_class = Class.new(described_class)
        batch_class.instance_variable_set(:@batch_groups, [described_class::Group.new([], {})])

        result = batch_class.call(test: "data")

        expect(result.status).to eq("success")
      end

      it "handles groups with empty options" do
        task = simple_task
        batch_class = Class.new(described_class) do
          process task
        end

        result = batch_class.call(test: "data")

        expect(result.status).to eq("success")
        expect(result.context.executed).to be(true)
      end
    end
  end

  describe "integration scenarios" do
    let(:counter_task_one) do
      Class.new(CMDx::Task) do
        def call
          context.counter ||= 0
          context.counter += 1
          context.executed_tasks ||= []
          context.executed_tasks << "counter_#{context.counter}"
        end
      end
    end

    let(:failing_task) do
      Class.new(CMDx::Task) do
        def call
          context.executed_tasks ||= []
          context.executed_tasks << "failing_task"
          fail!(reason: "Task failed")
        end
      end
    end

    it "executes simple batch workflow" do
      task = counter_task_one
      batch_class = Class.new(described_class) do
        process task
        process task
      end

      result = batch_class.call(test: "data")

      expect(result.status).to eq("success")
      expect(result.context.executed_tasks).to eq(%w[counter_1 counter_2])
    end

    it "stops execution on first failure with default halt behavior" do
      # Create separate counter task classes to avoid shared state
      counter_task_two = Class.new(CMDx::Task) do
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
      batch_class = Class.new(described_class) do
        process task_one
        process failing
        process task_two
      end

      result = batch_class.call(test: "data")

      expect(result.context.executed_tasks).to eq(%w[counter_1 failing_task])
      expect(result.status).to eq("failed")
    end

    it "continues execution with custom halt behavior" do
      counter = counter_task_one
      failing = failing_task
      batch_class = Class.new(described_class) do
        process counter
        process failing, batch_halt: []
        process counter
      end

      result = batch_class.call(test: "data")

      expect(result.context.executed_tasks).to eq(%w[counter_1 failing_task counter_2])
      expect(result.status).to eq("success")
    end

    it "handles conditional execution with context data" do
      counter = counter_task_one
      conditional_task = Class.new(CMDx::Task) do
        def call
          context.conditional_executed = true
        end
      end

      batch_class = Class.new(described_class) do
        process counter
        process conditional_task, if: proc { context.counter > 0 }
      end

      result = batch_class.call(test: "data")

      expect(result.context.conditional_executed).to be(true)
      expect(result.status).to eq("success")
    end

    it "handles nested batch execution" do
      counter = counter_task_one
      inner_batch = Class.new(described_class) do
        process counter
        process counter
      end

      outer_batch = Class.new(described_class) do
        process counter
        process inner_batch
        process counter
      end

      result = outer_batch.call(test: "data")

      expect(result.status).to eq("success")
      expect(result.context.counter).to eq(4)
    end

    it "preserves context across all tasks" do
      data_task = Class.new(CMDx::Task) do
        def call
          context.shared_data ||= []
          context.shared_data << "task_#{object_id}"
        end
      end

      batch_class = Class.new(described_class) do
        process data_task
        process data_task
        process data_task
      end

      result = batch_class.call(test: "data")

      expect(result.status).to eq("success")
      expect(result.context.shared_data.size).to eq(3)
      expect(result.context.shared_data.all? { |item| item.start_with?("task_") }).to be(true)
    end
  end
end

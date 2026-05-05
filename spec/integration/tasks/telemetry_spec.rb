# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task telemetry", type: :feature do
  let(:events) { [] }
  let(:sub) { ->(event) { events << event } }

  def with_telemetry(task, *names)
    names.each { |n| task.telemetry.subscribe(n, sub) }
    task
  end

  describe "lifecycle events" do
    it "emits task_started and task_executed in order for a success" do
      task = with_telemetry(create_successful_task, :task_started, :task_executed)

      result = task.execute

      expect(events.map(&:name)).to eq(%i[task_started task_executed])
      expect(events.last.payload[:result]).to be(result)
      expect(events.last.task).to be(task)
    end

    it "emits task_rolled_back between failure and task_executed" do
      task = with_telemetry(
        create_failing_task(reason: "boom") { define_method(:rollback) { nil } },
        :task_started, :task_rolled_back, :task_executed
      )

      task.execute

      expect(events.map(&:name)).to eq(%i[task_started task_rolled_back task_executed])
    end

    it "emits task_retried with the attempt number" do
      task = with_telemetry(
        create_flaky_task(failures: 2) { retry_on CMDx::TestError, limit: 3, delay: 0 },
        :task_retried
      )

      task.execute

      expect(events.map(&:name)).to eq(%i[task_retried task_retried])
      expect(events.map { |e| e.payload[:attempt] }).to eq([1, 2])
    end

    it "emits task_deprecated for deprecated tasks" do
      task = with_telemetry(
        create_successful_task { deprecation :log },
        :task_deprecated
      )

      task.execute

      expect(events.map(&:name)).to eq(%i[task_deprecated])
    end
  end

  describe "event payload" do
    it "carries cid, tid, task class, payload and timestamp" do
      task = with_telemetry(create_successful_task, :task_executed)

      before = Time.now.utc
      result = task.execute

      event = events.first
      expect(event).to have_attributes(
        name: :task_executed,
        cid: result.cid,
        type: task.type,
        task:,
        tid: result.tid
      )
      expect(event.payload[:result]).to be(result)
      expect(event.timestamp).to be_a(Time).and(be >= before)
    end
  end

  describe "subscriber registration" do
    it "supports both callables and blocks" do
      task = create_successful_task
      task.telemetry.subscribe(:task_executed) { |e| events << e }

      task.execute
      expect(events.size).to eq(1)
    end

    it "rejects non-callables" do
      expect { create_successful_task.telemetry.subscribe(:task_executed, :nope) }
        .to raise_error(ArgumentError, /must respond to #call/)
    end

    it "rejects callable and block together" do
      expect do
        create_successful_task.telemetry.subscribe(:task_executed, sub) { |_| nil }
      end.to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "rejects unknown events" do
      expect { create_successful_task.telemetry.subscribe(:nope, sub) }
        .to raise_error(ArgumentError, /unknown event/)
    end

    it "unsubscribe removes a specific subscriber" do
      task = with_telemetry(create_successful_task, :task_executed)
      task.telemetry.unsubscribe(:task_executed, sub)

      task.execute

      expect(events).to be_empty
    end
  end

  describe "zero-cost when no subscribers" do
    it "produces no events" do
      create_successful_task.execute
      expect(events).to be_empty
    end
  end

  describe "inheritance" do
    it "child inherits parent subscribers and adds its own" do
      parent_events = []
      parent = create_successful_task(name: "Parent") do
        telemetry.subscribe(:task_executed, ->(e) { parent_events << e })
      end

      child_events = []
      child = create_successful_task(base: parent, name: "Child") do
        telemetry.subscribe(:task_executed, ->(e) { child_events << e })
      end

      child.execute

      expect(parent_events.size).to eq(1)
      expect(child_events.size).to eq(1)
    end

    it "does not leak child subscribers back to the parent" do
      parent_events = []
      parent = create_successful_task(name: "Parent2") do
        telemetry.subscribe(:task_executed, ->(e) { parent_events << e })
      end

      child_events = []
      _child = create_successful_task(base: parent, name: "Child2") do
        telemetry.subscribe(:task_executed, ->(e) { child_events << e })
      end

      parent.execute

      expect(parent_events.size).to eq(1)
      expect(child_events).to be_empty
    end
  end

  describe "global configuration" do
    it "global subscribers are seeded into new tasks" do
      global = []
      CMDx.configuration.telemetry.subscribe(:task_executed, ->(e) { global << e })

      create_successful_task.execute

      expect(global.size).to eq(1)
    end
  end
end

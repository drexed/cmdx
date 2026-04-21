# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Runtime do
  describe ".execute" do
    it "delegates to a new Runtime instance" do
      task = create_successful_task.new
      runtime = instance_double(described_class)

      expect(described_class).to receive(:new).with(task, strict: true).and_return(runtime)
      expect(runtime).to receive(:execute)

      described_class.execute(task, strict: true)
    end
  end

  describe "#execute" do
    context "with a successful task" do
      it "returns a success result" do
        result = described_class.execute(create_successful_task.new)

        expect(result).to have_attributes(
          state: "complete",
          status: "success",
          success?: true
        )
      end

      it "records a monotonic duration" do
        result = described_class.execute(create_successful_task.new)
        expect(result.duration).to be_positive
      end

      it "adds the result to the chain" do
        result = described_class.execute(create_successful_task.new)
        expect(result.chain.to_a).to eq([result])
      end
    end

    context "with a failing task" do
      it "returns a failed result" do
        result = described_class.execute(create_failing_task(reason: "nope").new)
        expect(result).to have_attributes(status: "failed", reason: "nope")
      end
    end

    context "with a task that raises" do
      it "wraps the error in a failed result with the cause" do
        task = create_erroring_task(reason: "broken").new
        result = described_class.execute(task)

        expect(result.status).to eq("failed")
        expect(result.cause).to be_a(StandardError)
        expect(result.cause.message).to eq("broken")
      end
    end

    context "when strict and the task fails" do
      it "re-raises the fault" do
        task = create_failing_task(reason: "nope").new
        expect { described_class.execute(task, strict: true) }
          .to raise_error(CMDx::Fault, "nope")
      end

      it "does not raise for a successful task" do
        task = create_successful_task.new
        expect { described_class.execute(task, strict: true) }.not_to raise_error
      end
    end

    describe "chain lifecycle" do
      it "creates a new chain when none is active and clears it afterwards" do
        expect(CMDx::Chain.current).to be_nil
        described_class.execute(create_successful_task.new)
        expect(CMDx::Chain.current).to be_nil
      end

      it "reuses the current chain when nested" do
        outer = create_task_class(name: "OuterTask") do
          define_method(:work) { context.inner_id = CMDx::Chain.current.id }
        end

        result = described_class.execute(outer.new)
        expect(result.cid).to eq(result.context.inner_id)
      end
    end

    describe "freezing on teardown" do
      it "freezes the task, its errors, and (at the root) the context" do
        task = create_successful_task.new
        described_class.execute(task)

        expect(task).to be_frozen
        expect(task.errors).to be_frozen
        expect(task.context).to be_frozen
      end
    end

    describe "telemetry" do
      it "emits task_started and task_executed events" do
        events = []
        task_class = create_successful_task
        task_class.telemetry.subscribe(:task_started) { |e| events << e.name }
        task_class.telemetry.subscribe(:task_executed) { |e| events << e.name }

        described_class.execute(task_class.new)
        expect(events).to eq(%i[task_started task_executed])
      end
    end

    describe "rollback" do
      it "invokes #rollback when the task fails" do
        task_class = create_task_class(name: "RollbackTask") do
          define_method(:work) { fail!("bad") }
          define_method(:rollback) { context.rolled_back = true }
        end
        task = task_class.new

        result = described_class.execute(task)

        expect(result.status).to eq("failed")
        expect(result.rolled_back?).to be(true)
        expect(task.context.rolled_back).to be(true)
      end

      it "does not invoke rollback on success" do
        task_class = create_task_class(name: "NoRollbackTask") do
          define_method(:work) { nil }
          define_method(:rollback) { context.rolled_back = true }
        end

        result = described_class.execute(task_class.new)
        expect(result.rolled_back?).to be(false)
      end
    end
  end
end

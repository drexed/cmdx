# frozen_string_literal: true

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

      it "passes the chain xid through every event" do
        CMDx.configuration.correlation_id = -> { "req-xyz" }
        events = []
        task_class = create_successful_task
        task_class.telemetry.subscribe(:task_started) { |e| events << e }
        task_class.telemetry.subscribe(:task_executed) { |e| events << e }

        described_class.execute(task_class.new)
        expect(events.map(&:xid)).to eq(%w[req-xyz req-xyz])
      end
    end

    describe "xid (correlation id)" do
      it "leaves xid nil when no resolver is configured" do
        result = described_class.execute(create_successful_task.new)
        expect(result.xid).to be_nil
      end

      it "resolves xid from the configured callable on root chain creation" do
        CMDx.configuration.correlation_id = -> { "req-abc" }
        result = described_class.execute(create_successful_task.new)
        expect(result.xid).to eq("req-abc")
      end

      it "invokes the resolver exactly once per root execution" do
        calls = 0
        CMDx.configuration.correlation_id = lambda do
          calls += 1
          "req-#{calls}"
        end

        inner = create_task_class(name: "InnerXidTask") do
          define_method(:work) { context.inner_xid = CMDx::Chain.current.xid }
        end
        outer = create_task_class(name: "OuterXidTask") do
          define_method(:work) do
            inner.execute(context)
            context.outer_xid = CMDx::Chain.current.xid
          end
        end

        result = described_class.execute(outer.new)
        expect(calls).to eq(1)
        expect(result.xid).to eq("req-1")
        expect(result.context.inner_xid).to eq("req-1")
        expect(result.context.outer_xid).to eq("req-1")
      end

      it "shares the xid across every result in the chain" do
        CMDx.configuration.correlation_id = -> { "shared" }

        inner = create_task_class(name: "InnerSharedXidTask") do
          define_method(:work) { nil }
        end
        outer = create_task_class(name: "OuterSharedXidTask") do
          define_method(:work) { inner.execute(context) }
        end

        result = described_class.execute(outer.new)
        expect(result.chain.map(&:xid).uniq).to eq(["shared"])
      end

      it "lets the resolver return nil" do
        CMDx.configuration.correlation_id = -> {}
        result = described_class.execute(create_successful_task.new)
        expect(result.xid).to be_nil
      end

      it "propagates exceptions raised by the resolver and leaves no chain behind" do
        CMDx.configuration.correlation_id = -> { raise "bad resolver" }
        expect { described_class.execute(create_successful_task.new) }
          .to raise_error(RuntimeError, "bad resolver")
        expect(CMDx::Chain.current).to be_nil
      end
    end

    describe "signals from middlewares and callbacks" do
      it "halts as failed when a middleware calls fail! before yielding" do
        task_class = create_task_class(name: "MwFailBeforeYield") do
          define_method(:work) { context.work_ran = true }
        end
        task_class.register :middleware, lambda { |t, &blk|
          t.fail!("blocked", code: :gate)
          blk.call
        }

        result = described_class.execute(task_class.new)

        expect(result).to have_attributes(status: "failed", reason: "blocked")
        expect(result.metadata).to include(code: :gate)
        expect(result.context).not_to respond_to(:work_ran)
      end

      it "halts as skipped when a middleware calls skip! before yielding" do
        task_class = create_task_class(name: "MwSkipBeforeYield") do
          define_method(:work) { context.work_ran = true }
        end
        task_class.register :middleware, ->(t, &_blk) { t.skip!("duplicate") }

        result = described_class.execute(task_class.new)

        expect(result).to have_attributes(status: "skipped", reason: "duplicate")
      end

      it "raises a Fault under strict mode for a middleware-thrown failure" do
        task_class = create_task_class(name: "MwFailStrict") do
          define_method(:work) { nil }
        end
        task_class.register :middleware, ->(t, &_blk) { t.fail!("no") }

        expect { described_class.execute(task_class.new, strict: true) }
          .to raise_error(CMDx::Fault, "no")
      end

      it "halts when a before_execution callback throws fail!" do
        task_class = create_task_class(name: "CbFailBeforeExec") do
          before_execution { fail!("guarded") }
          define_method(:work) { context.work_ran = true }
        end

        result = described_class.execute(task_class.new)

        expect(result).to have_attributes(status: "failed", reason: "guarded")
      end

      it "still finalizes the result when #rollback raises an exception that a wrapping middleware swallows" do
        swallow_mw = lambda do |_task, &blk|
          blk.call
        rescue StandardError
          # mimics ActiveRecord::Base.transaction silently catching ActiveRecord::Rollback
        end

        task_class = create_task_class(name: "RollbackSwallowedTask") do
          register :middleware, swallow_mw
          define_method(:work) { fail!("bad") }
          define_method(:rollback) { raise "transaction rollback" }
        end

        result = described_class.execute(task_class.new)

        expect(result).not_to be_nil
        expect(result).to have_attributes(status: "failed", reason: "bad", rolled_back?: true)
      end

      it "pushes the result onto the chain exactly once when a middleware halts the task" do
        task_class = create_task_class(name: "MwFailChain") do
          define_method(:work) { nil }
        end
        task_class.register :middleware, ->(t, &_blk) { t.fail!("halt") }

        result = described_class.execute(task_class.new)

        expect(result.chain.to_a).to eq([result])
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

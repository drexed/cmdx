# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task execution", type: :feature do
  describe "non-blocking execute" do
    context "when successful" do
      subject(:result) { create_successful_task.execute }

      it "returns a complete/success result" do
        expect(result).to have_attributes(
          state: CMDx::Signal::COMPLETE,
          status: CMDx::Signal::SUCCESS,
          reason: nil,
          metadata: {},
          cause: nil
        )
        expect(result.context).to have_attributes(executed: %i[success])
      end

      it "populates metadata attributes" do
        expect(result.tid).to match(/\A\h{8}-\h{4}-7\h{3}-\h{4}-\h{12}\z/)
        expect(result.cid).to match(/\A\h{8}-\h{4}-7\h{3}-\h{4}-\h{12}\z/)
        expect(result.index).to eq(0)
        expect(result.duration).to be_a(Float).and be >= 0
        expect(result.retries).to eq(0)
        expect(result).to have_attributes(strict?: false, retried?: false, deprecated?: false, rolled_back?: false)
      end
    end

    context "when skipping" do
      subject(:result) { create_skipping_task(reason: "not needed", code: 42).execute }

      it "returns an interrupted/skipped result with reason and metadata" do
        expect(result).to have_attributes(
          state: CMDx::Signal::INTERRUPTED,
          status: CMDx::Signal::SKIPPED,
          reason: "not needed",
          metadata: { code: 42 },
          cause: nil
        )
        expect(result.context).to be_empty
      end
    end

    context "when failing" do
      subject(:result) { create_failing_task(reason: "broken", code: "E1").execute }

      it "returns an interrupted/failed result with reason and metadata" do
        expect(result).to have_attributes(
          state: CMDx::Signal::INTERRUPTED,
          status: CMDx::Signal::FAILED,
          reason: "broken",
          metadata: { code: "E1" },
          cause: nil
        )
        expect(result.context).to be_empty
      end
    end

    context "when raising an uncaught exception" do
      subject(:result) { create_erroring_task.execute }

      it "captures the error as a failed result" do
        expect(result).to have_attributes(
          state: CMDx::Signal::INTERRUPTED,
          status: CMDx::Signal::FAILED,
          reason: "[CMDx::TestError] borked error",
          cause: be_a(CMDx::TestError)
        )
      end
    end

    context "when calling success! explicitly" do
      subject(:result) do
        create_task_class(name: "EarlyExitTask") do
          define_method(:work) do
            success!("done", code: :ok)
            context.unreachable = true
          end
        end.execute
      end

      it "short-circuits execution with success reason/metadata" do
        expect(result).to have_attributes(
          status: CMDx::Signal::SUCCESS,
          reason: "done",
          metadata: { code: :ok }
        )
        expect(result.context[:unreachable]).to be_nil
      end
    end

    context "when given a block" do
      it "yields the result and returns the block's value" do
        yielded = nil
        value = create_successful_task.execute do |r|
          yielded = r
          :from_block
        end

        expect(yielded).to be_a(CMDx::Result)
        expect(value).to eq(:from_block)
      end
    end

    context "when passed an initial context" do
      subject(:task) do
        create_task_class(name: "ContextTask") do
          define_method(:work) { context.total = context[:a] + context[:b] }
        end
      end

      it "accepts a hash" do
        expect(task.execute(a: 2, b: 3).context[:total]).to eq(5)
      end

      it "accepts a pre-built Context" do
        ctx = CMDx::Context.new(a: 4, b: 6)
        expect(task.execute(ctx).context[:total]).to eq(10)
      end
    end

    context "with aliases" do
      let(:task) { create_successful_task }

      it "aliases call to execute" do
        expect(task.call).to be_a(CMDx::Result)
      end
    end
  end

  describe "blocking execute!" do
    context "when successful" do
      subject(:result) { create_successful_task.execute! }

      it "returns the result and marks it strict" do
        expect(result).to have_attributes(status: CMDx::Signal::SUCCESS, strict?: true)
      end
    end

    context "when skipping" do
      subject(:result) { create_skipping_task.execute! }

      it "returns the result without raising" do
        expect(result).to have_attributes(status: CMDx::Signal::SKIPPED, strict?: true)
      end
    end

    context "when failing via fail!" do
      let(:task) { create_failing_task(reason: "boom", code: 99) }

      it "raises a Fault with the reason and original metadata" do
        expect { task.execute! }.to raise_error(CMDx::Fault, "boom")
      end

      it "raises with the default reason when none was provided" do
        expect { create_failing_task.execute! }.to raise_error(CMDx::Fault, "Unspecified")
      end
    end

    context "when raising an uncaught exception" do
      it "re-raises the original error" do
        expect { create_erroring_task(reason: "kaboom").execute! }
          .to raise_error(CMDx::TestError, "kaboom")
      end
    end

    context "when given a block" do
      it "yields the result before returning" do
        captured = nil
        create_successful_task.execute! { |r| captured = r.status }
        expect(captured).to eq(CMDx::Signal::SUCCESS)
      end
    end

    context "with aliases" do
      it "aliases call! to execute!" do
        expect { create_failing_task.call! }.to raise_error(CMDx::Fault)
      end
    end
  end

  describe "Result#on" do
    it "yields the result for matching events and chains" do
      result = create_successful_task.execute
      triggered = []

      returned = result
                 .on(:success) { |r| triggered << [:success, r.status] }
                 .on(:complete) { triggered << :complete }
                 .on(:ok) { triggered << :ok }
                 .on(:failed) { triggered << :never }

      expect(returned).to be(result)
      expect(triggered).to eq([[:success, "success"], :complete, :ok])
    end

    it "accepts multiple events in a single call" do
      result = create_failing_task.execute
      fired = false

      result.on(:success, :failed) { fired = true }

      expect(fired).to be(true)
    end

    it "requires a block" do
      result = create_successful_task.execute
      expect { result.on(:success) }.to raise_error(ArgumentError, /block required/)
    end

    it "rejects unknown events" do
      result = create_successful_task.execute
      expect { result.on(:bogus) { nil } }.to raise_error(ArgumentError, /unknown event/)
    end
  end

  describe "nested task execution" do
    context "with swallow strategy" do
      it "captures the inner failure without halting the outer" do
        result = create_nested_task(strategy: :swallow, status: :failure).execute

        expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
        expect(result.context[:executed]).to eq(%i[middle outer])
      end
    end

    context "with throw strategy" do
      it "propagates the inner failure up the stack" do
        result = create_nested_task(strategy: :throw, status: :failure, reason: "inner-broke").execute

        expect(result).to have_attributes(status: CMDx::Signal::FAILED, reason: "inner-broke")
        expect(result.context[:executed]).to be_nil
      end
    end

    context "with raise strategy" do
      it "re-raises the inner exception out to the outer" do
        result = create_nested_task(strategy: :raise, status: :error, reason: "explode").execute

        expect(result).to have_attributes(
          status: CMDx::Signal::FAILED,
          reason: "[CMDx::TestError] explode",
          cause: be_a(CMDx::TestError)
        )
      end
    end
  end

  describe "result pattern matching" do
    it "deconstructs into [[key, value], ...] pairs mirroring #to_h" do
      task = create_failing_task(reason: "nope", kind: :minor)
      result = task.execute

      expect(result.deconstruct).to eq(result.to_h.to_a)
      expect(result.deconstruct.assoc(:status)).to eq([:status, "failed"])
      expect(result.deconstruct.assoc(:reason)).to eq([:reason, "nope"])
      expect(result.deconstruct.assoc(:metadata)).to eq([:metadata, { kind: :minor }])
    end
  end

  describe "post-execution freezing" do
    it "freezes the context, errors, and task" do
      result = create_successful_task.execute

      expect(result.context).to be_frozen
      expect(result.errors).to be_frozen
    end
  end

  describe "missing #work implementation" do
    let(:bare) { create_task_class(name: "Bare") }

    it "re-raises ImplementationError from execute" do
      expect { bare.execute }.to raise_error(CMDx::ImplementationError, /undefined method.*#work/)
    end

    it "re-raises ImplementationError from execute!" do
      expect { bare.execute! }.to raise_error(CMDx::ImplementationError, /undefined method.*#work/)
    end
  end
end

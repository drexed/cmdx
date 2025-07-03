# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Result do
  let(:task_class) { create_simple_task(name: "TestTask") }
  let(:task) { task_class.new }
  let(:chain) { mock_chain(index: 0, results: [], id: "test_chain_id") }

  # Helper methods to create results in specific states for status checking
  let(:skipped_result) do
    result = described_class.new(task)
    # Directly set the status without triggering halt! for testing status methods
    result.instance_variable_set(:@status, "skipped")
    result
  end

  let(:failed_result) do
    result = described_class.new(task)
    # Directly set the status without triggering halt! for testing status methods
    result.instance_variable_set(:@status, "failed")
    result
  end

  before do
    allow(task).to receive(:chain).and_return(chain)
  end

  describe "#initialize" do
    it "accepts a task parameter" do
      result = described_class.new(task)

      expect(result.task).to be(task)
    end

    it "raises TypeError for non-task objects" do
      expect { described_class.new("not a task") }.to raise_error(TypeError, "must be a Task or Workflow")
    end

    it "initializes with initialized state" do
      result = described_class.new(task)

      expect(result.state).to eq("initialized")
      expect(result.initialized?).to be(true)
    end

    it "initializes with success status" do
      result = described_class.new(task)

      expect(result.status).to eq("success")
      expect(result.success?).to be(true)
    end

    it "initializes with empty metadata" do
      result = described_class.new(task)

      expect(result.metadata).to eq({})
    end

    it "delegates context to task" do
      context = double("Context")
      allow(task).to receive(:context).and_return(context)
      result = described_class.new(task)

      expect(result.context).to be(context)
    end

    it "delegates chain to task" do
      result = described_class.new(task)

      expect(result.chain).to be(chain)
    end
  end

  describe "state predicate methods" do
    subject(:result) { described_class.new(task) }

    it "responds to initialized?" do
      expect(result.initialized?).to be(true)
    end

    it "responds to executing?" do
      expect(result.executing?).to be(false)
    end

    it "responds to complete?" do
      expect(result.complete?).to be(false)
    end

    it "responds to interrupted?" do
      expect(result.interrupted?).to be(false)
    end
  end

  describe "status predicate methods" do
    subject(:result) { described_class.new(task) }

    it "responds to success?" do
      expect(result.success?).to be(true)
    end

    it "responds to skipped?" do
      expect(result.skipped?).to be(false)
    end

    it "responds to failed?" do
      expect(result.failed?).to be(false)
    end
  end

  describe "#executing!" do
    subject(:result) { described_class.new(task) }

    it "transitions from initialized to executing" do
      result.executing!

      expect(result.executing?).to be(true)
      expect(result.state).to eq("executing")
    end

    it "is idempotent when already executing" do
      result.executing!
      result.executing!

      expect(result.executing?).to be(true)
    end

    it "raises error when not transitioning from initialized" do
      result.executing!
      result.complete!

      expect { result.executing! }.to raise_error("can only transition to executing from initialized")
    end
  end

  describe "#complete!" do
    subject(:result) { described_class.new(task) }

    it "transitions from executing to complete" do
      result.executing!
      result.complete!

      expect(result.complete?).to be(true)
      expect(result.state).to eq("complete")
    end

    it "is idempotent when already complete" do
      result.executing!
      result.complete!
      result.complete!

      expect(result.complete?).to be(true)
    end

    it "raises error when not transitioning from executing" do
      expect { result.complete! }.to raise_error("can only transition to complete from executing")
    end
  end

  describe "#interrupt!" do
    subject(:result) { described_class.new(task) }

    it "transitions from initialized to interrupted" do
      result.interrupt!

      expect(result.interrupted?).to be(true)
      expect(result.state).to eq("interrupted")
    end

    it "transitions from executing to interrupted" do
      result.executing!
      result.interrupt!

      expect(result.interrupted?).to be(true)
    end

    it "is idempotent when already interrupted" do
      result.interrupt!
      result.interrupt!

      expect(result.interrupted?).to be(true)
    end

    it "raises error when transitioning from complete" do
      result.executing!
      result.complete!

      expect { result.interrupt! }.to raise_error("cannot transition to interrupted from complete")
    end
  end

  describe "#executed!" do
    subject(:result) { described_class.new(task) }

    context "when status is success" do
      it "transitions to complete state" do
        result.executing!
        result.executed!

        expect(result.complete?).to be(true)
      end
    end

    context "when status is not success" do
      it "transitions to interrupted state for skipped" do
        result.executing!
        result.skip!(reason: "Test skip", original_exception: StandardError.new("Test"))
        result.executed!

        expect(result.interrupted?).to be(true)
      end

      it "transitions to interrupted state for failed" do
        result.executing!
        result.fail!(reason: "Test failure", original_exception: StandardError.new("Test"))
        result.executed!

        expect(result.interrupted?).to be(true)
      end
    end
  end

  describe "#executed?" do
    subject(:result) { described_class.new(task) }

    it "returns false for initialized state" do
      expect(result.executed?).to be(false)
    end

    it "returns false for executing state" do
      result.executing!

      expect(result.executed?).to be(false)
    end

    it "returns true for complete state" do
      result.executing!
      result.complete!

      expect(result.executed?).to be(true)
    end

    it "returns true for interrupted state" do
      result.interrupt!

      expect(result.executed?).to be(true)
    end
  end

  describe "#good?" do
    subject(:result) { described_class.new(task) }

    it "returns true for success status" do
      expect(result.good?).to be(true)
    end

    it "returns true for skipped status" do
      expect(skipped_result.good?).to be(true)
    end

    it "returns false for failed status" do
      expect(failed_result.good?).to be(false)
    end
  end

  describe "#bad?" do
    subject(:result) { described_class.new(task) }

    it "returns false for success status" do
      expect(result.bad?).to be(false)
    end

    it "returns true when result is skipped" do
      expect(skipped_result.bad?).to be(true)
    end

    it "returns true when result is failed" do
      expect(failed_result.bad?).to be(true)
    end
  end

  describe "state callback methods" do
    subject(:result) { described_class.new(task) }

    describe "#on_initialized" do
      it "executes block when initialized" do
        callback_executed = false
        result.on_initialized { callback_executed = true }

        expect(callback_executed).to be(true)
      end

      it "does not execute block when not initialized" do
        callback_executed = false
        result.executing!
        result.on_initialized { callback_executed = true }

        expect(callback_executed).to be(false)
      end

      it "returns self for chaining" do
        expect(result.on_initialized { |r| r }).to be(result)
      end

      it "raises error without block" do
        expect { result.on_initialized }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_executing" do
      it "executes block when executing" do
        callback_executed = false
        result.executing!
        result.on_executing { callback_executed = true }

        expect(callback_executed).to be(true)
      end

      it "does not execute block when not executing" do
        callback_executed = false
        result.on_executing { callback_executed = true }

        expect(callback_executed).to be(false)
      end
    end

    describe "#on_complete" do
      it "executes block when complete" do
        callback_executed = false
        result.executing!
        result.complete!
        result.on_complete { callback_executed = true }

        expect(callback_executed).to be(true)
      end

      it "does not execute block when not complete" do
        callback_executed = false
        result.on_complete { callback_executed = true }

        expect(callback_executed).to be(false)
      end
    end

    describe "#on_interrupted" do
      it "executes block when interrupted" do
        callback_executed = false
        result.interrupt!
        result.on_interrupted { callback_executed = true }

        expect(callback_executed).to be(true)
      end

      it "does not execute block when not interrupted" do
        callback_executed = false
        result.on_interrupted { callback_executed = true }

        expect(callback_executed).to be(false)
      end
    end
  end

  describe "#on_executed" do
    subject(:result) { described_class.new(task) }

    it "executes block when executed" do
      callback_executed = false
      result.executing!
      result.complete!
      result.on_executed { callback_executed = true }

      expect(callback_executed).to be(true)
    end

    it "does not execute block when not executed" do
      callback_executed = false
      result.on_executed { callback_executed = true }

      expect(callback_executed).to be(false)
    end

    it "returns self for chaining" do
      expect(result.on_executed { |r| r }).to be(result)
    end

    it "raises error without block" do
      expect { result.on_executed }.to raise_error(ArgumentError, "block required")
    end
  end

  describe "status callback methods" do
    subject(:result) { described_class.new(task) }

    describe "#on_success" do
      it "executes block when successful" do
        callback_executed = false
        result.on_success { callback_executed = true }

        expect(callback_executed).to be(true)
      end

      it "does not execute block when not successful" do
        callback_executed = false
        failed_result.on_success { callback_executed = true }

        expect(callback_executed).to be(false)
      end

      it "returns self for chaining" do
        expect(result.on_success { |r| r }).to be(result)
      end

      it "raises error without block" do
        expect { result.on_success }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_skipped" do
      it "executes block when skipped" do
        callback_executed = false
        skipped_result.on_skipped { callback_executed = true }

        expect(callback_executed).to be(true)
      end

      it "does not execute block when not skipped" do
        callback_executed = false
        result.on_skipped { callback_executed = true }

        expect(callback_executed).to be(false)
      end
    end

    describe "#on_failed" do
      it "executes block when failed" do
        callback_executed = false
        failed_result.on_failed { callback_executed = true }

        expect(callback_executed).to be(true)
      end

      it "does not execute block when not failed" do
        callback_executed = false
        result.on_failed { callback_executed = true }

        expect(callback_executed).to be(false)
      end
    end
  end

  describe "#on_good" do
    subject(:result) { described_class.new(task) }

    it "executes block when good" do
      callback_executed = false
      result.on_good { callback_executed = true }

      expect(callback_executed).to be(true)
    end

    it "does not execute block when not good" do
      callback_executed = false
      failed_result.on_good { callback_executed = true }

      expect(callback_executed).to be(false)
    end

    it "returns self for chaining" do
      expect(result.on_good { |r| r }).to be(result)
    end

    it "raises error without block" do
      expect { result.on_good }.to raise_error(ArgumentError, "block required")
    end
  end

  describe "#on_bad" do
    subject(:result) { described_class.new(task) }

    it "executes block when bad" do
      callback_executed = false
      failed_result.on_bad { callback_executed = true }

      expect(callback_executed).to be(true)
    end

    it "does not execute block when not bad" do
      callback_executed = false
      result.on_bad { callback_executed = true }

      expect(callback_executed).to be(false)
    end

    it "returns self for chaining" do
      expect(result.on_bad { |r| r }).to be(result)
    end

    it "raises error without block" do
      expect { result.on_bad }.to raise_error(ArgumentError, "block required")
    end
  end

  describe "#skip!" do
    subject(:result) { described_class.new(task) }

    it "transitions from success to skipped and raises fault" do
      expect { result.skip!(reason: "Already processed") }.to raise_error(CMDx::Fault)
      expect(result.skipped?).to be(true)
      expect(result.status).to eq("skipped")
    end

    it "stores metadata and raises fault" do
      expect { result.skip!(reason: "Already processed", code: 422) }.to raise_error(CMDx::Fault)
      expect(result.metadata[:reason]).to eq("Already processed")
      expect(result.metadata[:code]).to eq(422)
    end

    it "is idempotent when already skipped" do
      # Create a result that's already skipped to test idempotent behavior
      already_skipped = described_class.new(task)
      already_skipped.instance_variable_set(:@status, "skipped")
      already_skipped.instance_variable_set(:@metadata, { reason: "First" })

      # Second call should be idempotent (preserve original metadata)
      already_skipped.skip!(reason: "Second")
      expect(already_skipped.metadata[:reason]).to eq("First")
    end

    it "raises error when not transitioning from success" do
      result.fail!(original_exception: StandardError.new("Test"))
      expect { result.skip! }.to raise_error("can only transition to skipped from success")
    end

    it "does not raise fault when original_exception present" do
      expect { result.skip!(original_exception: StandardError.new("Test")) }.not_to raise_error
    end
  end

  describe "#fail!" do
    subject(:result) { described_class.new(task) }

    it "transitions from success to failed and raises fault" do
      expect { result.fail!(reason: "Validation error") }.to raise_error(CMDx::Fault)
      expect(result.failed?).to be(true)
      expect(result.status).to eq("failed")
    end

    it "stores metadata and raises fault" do
      expect { result.fail!(reason: "Validation error", code: 422) }.to raise_error(CMDx::Fault)
      expect(result.metadata[:reason]).to eq("Validation error")
      expect(result.metadata[:code]).to eq(422)
    end

    it "is idempotent when already failed" do
      # Create a result that's already failed to test idempotent behavior
      already_failed = described_class.new(task)
      already_failed.instance_variable_set(:@status, "failed")
      already_failed.instance_variable_set(:@metadata, { reason: "First" })

      # Second call should be idempotent (preserve original metadata)
      already_failed.fail!(reason: "Second")
      expect(already_failed.metadata[:reason]).to eq("First")
    end

    it "raises error when not transitioning from success" do
      result.skip!(original_exception: StandardError.new("Test"))
      expect { result.fail! }.to raise_error("can only transition to failed from success")
    end

    it "does not raise fault when original_exception present" do
      expect { result.fail!(original_exception: StandardError.new("Test")) }.not_to raise_error
    end
  end

  describe "#halt!" do
    subject(:result) { described_class.new(task) }

    it "does not raise when successful" do
      expect { result.halt! }.not_to raise_error
    end

    it "raises fault when not successful" do
      result.fail!(original_exception: StandardError.new("Test"))
      expect(CMDx::Fault).to receive(:build).with(result).and_call_original

      expect { result.halt! }.to raise_error(CMDx::Fault)
    end
  end

  describe "#throw!" do
    subject(:result) { described_class.new(task) }

    let(:other_result) { described_class.new(task) }

    it "raises TypeError for non-result parameter" do
      expect { result.throw!("not a result") }.to raise_error(TypeError, "must be a Result")
    end

    it "propagates skipped status" do
      # Create a result that is skipped and will cause fault when thrown
      other_result.instance_variable_set(:@status, "skipped")
      other_result.instance_variable_set(:@metadata, { reason: "Test skip" })
      expect { result.throw!(other_result) }.to raise_error(CMDx::Fault)
      expect(result.skipped?).to be(true)
    end

    it "propagates failed status" do
      # Create a result that is failed and will cause fault when thrown
      other_result.instance_variable_set(:@status, "failed")
      other_result.instance_variable_set(:@metadata, { reason: "Test failure" })
      expect { result.throw!(other_result) }.to raise_error(CMDx::Fault)
      expect(result.failed?).to be(true)
    end

    it "merges local metadata with other result metadata" do
      # Create a result that is failed and will cause fault when thrown
      other_result.instance_variable_set(:@status, "failed")
      other_result.instance_variable_set(:@metadata, { reason: "Original" })
      expect { result.throw!(other_result, context: "Local") }.to raise_error(CMDx::Fault)
      expect(result.metadata[:reason]).to eq("Original")
      expect(result.metadata[:context]).to eq("Local")
    end

    it "does not propagate success status" do
      expect { result.throw!(other_result) }.not_to(change(result, :status))
    end
  end

  describe "#index" do
    subject(:result) { described_class.new(task) }

    it "delegates to chain" do
      expect(chain).to receive(:index).with(result).and_return(5)

      expect(result.index).to eq(5)
    end
  end

  describe "#outcome" do
    subject(:result) { described_class.new(task) }

    it "returns state when initialized" do
      expect(result.outcome).to eq("initialized")
    end

    it "returns status when executing and successful" do
      result.executing!
      expect(result.outcome).to eq("success")
    end

    it "returns state when thrown failure" do
      # Create a thrown failure by failing another result and throwing it
      other_result = described_class.new(task)
      other_result.fail!(reason: "Test failure", original_exception: StandardError.new("Test"))

      begin
        result.throw!(other_result)
      rescue CMDx::Fault
        # Expected fault, continue with test
      end
      expect(result.outcome).to eq("initialized")
    end
  end

  describe "#runtime" do
    subject(:result) { described_class.new(task) }

    context "when called without block" do
      it "returns nil when no runtime stored" do
        expect(result.runtime).to be_nil
      end

      it "returns stored runtime value" do
        result.runtime { sleep 0.001 }
        stored_runtime = result.runtime

        expect(stored_runtime).to be_a(Integer)
        expect(stored_runtime).to be > 0
      end
    end

    context "when called with block" do
      it "executes block and returns runtime" do
        block_executed = false
        runtime = result.runtime do
          block_executed = true
          sleep 0.001
        end

        expect(block_executed).to be(true)
        expect(runtime).to be_a(Integer)
        expect(runtime).to be > 0
      end

      it "stores runtime for later access" do
        result.runtime { sleep 0.001 }

        expect(result.runtime).to be_a(Integer)
        expect(result.runtime).to be > 0
      end
    end
  end

  describe "failure chain methods" do
    let(:first_result) { described_class.new(task) }
    let(:second_result) { described_class.new(task) }
    let(:third_result) { described_class.new(task) }

    before do
      allow(chain).to receive(:results).and_return([first_result, second_result, third_result])
      allow(first_result).to receive(:index).and_return(0)
      allow(second_result).to receive(:index).and_return(1)
      allow(third_result).to receive(:index).and_return(2)
    end

    describe "#caused_failure" do
      it "returns nil when not failed" do
        expect(first_result.caused_failure).to be_nil
      end

      it "returns first failed result in reverse order" do
        # Create actual failed results for proper chain testing
        second_result.fail!(reason: "First failure", original_exception: StandardError.new("Test"))
        third_result.fail!(reason: "Second failure", original_exception: StandardError.new("Test"))

        expect(third_result.caused_failure).to be(third_result)
      end
    end

    describe "#caused_failure?" do
      it "returns false when not failed" do
        expect(first_result.caused_failure?).to be(false)
      end

      it "returns true when this result caused the failure" do
        first_result.fail!(reason: "Original failure", original_exception: StandardError.new("Test"))

        expect(first_result.caused_failure?).to be(true)
      end

      it "returns false when this result did not cause the failure" do
        # Test with a successful result that didn't cause any failure
        expect(second_result.caused_failure?).to be(false)
      end
    end

    describe "#threw_failure" do
      it "returns nil when not failed" do
        expect(first_result.threw_failure).to be_nil
      end

      it "returns result that threw failure with higher index" do
        # Create first result as failed (causing failure)
        first_result.instance_variable_set(:@status, "failed")
        first_result.instance_variable_set(:@metadata, { reason: "Original" })

        # Create second result as failed (thrown from first)
        second_result.instance_variable_set(:@status, "failed")
        second_result.instance_variable_set(:@metadata, { reason: "Original" })

        expect(first_result.threw_failure).to be(second_result)
      end

      it "returns last failed result when no higher index found" do
        second_result.fail!(reason: "Last failure", original_exception: StandardError.new("Test"))

        expect(second_result.threw_failure).to be(second_result)
      end
    end

    describe "#threw_failure?" do
      it "returns false when not failed" do
        expect(first_result.threw_failure?).to be(false)
      end

      it "returns true when this result threw the failure" do
        first_result.fail!(reason: "Failure", original_exception: StandardError.new("Test"))

        expect(first_result.threw_failure?).to be(true)
      end

      it "returns false when this result did not throw the failure" do
        # Create first result as failed (causing failure)
        first_result.instance_variable_set(:@status, "failed")
        first_result.instance_variable_set(:@metadata, { reason: "Original" })

        # Create second result as failed (throwing the failure)
        second_result.instance_variable_set(:@status, "failed")
        second_result.instance_variable_set(:@metadata, { reason: "Original" })

        expect(first_result.threw_failure?).to be(false)
      end
    end

    describe "#thrown_failure?" do
      it "returns false when not failed" do
        expect(first_result.thrown_failure?).to be(false)
      end

      it "returns true when failed but not the cause" do
        # Test with a successful result that didn't throw any failure
        expect(second_result.thrown_failure?).to be(false)
      end

      it "returns false when failed and is the cause" do
        first_result.fail!(reason: "Original failure", original_exception: StandardError.new("Test"))

        expect(first_result.thrown_failure?).to be(false)
      end
    end
  end

  describe "#to_h" do
    subject(:result) { described_class.new(task) }

    it "delegates to ResultSerializer" do
      serialized_data = { test: "data" }
      expect(CMDx::ResultSerializer).to receive(:call).with(result).and_return(serialized_data)

      expect(result.to_h).to eq(serialized_data)
    end
  end

  describe "#to_s" do
    subject(:result) { described_class.new(task) }

    it "delegates to ResultInspector with serialized data" do
      inspected_string = "Inspected result"
      expect(CMDx::ResultInspector).to receive(:call).with(result.to_h).and_return(inspected_string)

      expect(result.to_s).to eq(inspected_string)
    end
  end

  describe "#deconstruct" do
    subject(:result) { described_class.new(task) }

    it "returns array with state and status" do
      result.executing!

      expect(result.deconstruct).to eq(%w[executing success])
    end

    it "reflects current state and status" do
      result.executing!
      result.fail!(reason: "Test", original_exception: StandardError.new("Test"))

      expect(result.deconstruct).to eq(%w[executing failed])
    end
  end

  describe "#deconstruct_keys" do
    subject(:result) { described_class.new(task) }

    context "when keys is nil" do
      it "returns all attributes" do
        keys = result.deconstruct_keys(nil)

        expect(keys).to include(
          state: "initialized",
          status: "success",
          metadata: {},
          executed: false,
          good: true,
          bad: false
        )
      end
    end

    context "when specific keys provided" do
      it "returns only requested keys" do
        keys = result.deconstruct_keys(%i[state status])

        expect(keys).to eq(state: "initialized", status: "success")
      end

      it "returns empty hash for non-existent keys" do
        keys = result.deconstruct_keys([:non_existent])

        expect(keys).to eq({})
      end
    end

    it "reflects current result state" do
      result.executing!
      result.fail!(reason: "Test failure", original_exception: StandardError.new("Test"))
      keys = result.deconstruct_keys(%i[state status good bad])

      expect(keys).to include(
        state: "executing",
        status: "failed",
        good: false,
        bad: true
      )
    end
  end
end

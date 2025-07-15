# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Result do
  subject(:result) { described_class.new(task) }

  let(:task) { create_simple_task(name: "TestTask").new }

  describe ".new" do
    it "creates result with task" do
      expect(result.task).to eq(task)
    end

    it "initializes with initialized state" do
      expect(result).to be_initialized
    end

    it "initializes with success status" do
      expect(result).to be_success
    end

    it "initializes with empty metadata" do
      expect(result).to have_empty_metadata
    end

    it "raises TypeError for non-task" do
      expect { described_class.new("not a task") }.to raise_error(TypeError, "must be a Task or Workflow")
    end
  end

  describe "state predicate methods" do
    it "returns true for initialized state initially" do
      expect(result.initialized?).to be true
      expect(result.executing?).to be false
      expect(result.complete?).to be false
      expect(result.interrupted?).to be false
    end

    it "returns true for executing state after transition" do
      result.executing!

      expect(result.initialized?).to be false
      expect(result.executing?).to be true
      expect(result.complete?).to be false
      expect(result.interrupted?).to be false
    end

    it "returns true for complete state after transition" do
      result.executing!
      result.complete!

      expect(result.initialized?).to be false
      expect(result.executing?).to be false
      expect(result.complete?).to be true
      expect(result.interrupted?).to be false
    end

    it "returns true for interrupted state after transition" do
      result.executing!
      result.interrupt!

      expect(result.initialized?).to be false
      expect(result.executing?).to be false
      expect(result.complete?).to be false
      expect(result.interrupted?).to be true
    end
  end

  describe "status predicate methods" do
    it "returns true for success status initially" do
      expect(result.success?).to be true
      expect(result.skipped?).to be false
      expect(result.failed?).to be false
    end

    it "returns true for skipped status after transition" do
      result.skip!(original_exception: StandardError.new)

      expect(result.success?).to be false
      expect(result.skipped?).to be true
      expect(result.failed?).to be false
    end

    it "returns true for failed status after transition" do
      result.fail!(original_exception: StandardError.new)

      expect(result.success?).to be false
      expect(result.skipped?).to be false
      expect(result.failed?).to be true
    end
  end

  describe "state transitions" do
    describe "#executing!" do
      it "transitions from initialized to executing" do
        result.executing!

        expect(result).to be_executing
      end

      it "is idempotent" do
        result.executing!
        result.executing!

        expect(result).to be_executing
      end

      it "raises error when not transitioning from initialized" do
        result.executing!
        result.complete!

        expect { result.executing! }.to raise_error(/can only transition to executing from initialized/)
      end
    end

    describe "#complete!" do
      it "transitions from executing to complete" do
        result.executing!
        result.complete!

        expect(result).to be_complete
      end

      it "is idempotent" do
        result.executing!
        result.complete!
        result.complete!

        expect(result).to be_complete
      end

      it "raises error when not transitioning from executing" do
        expect { result.complete! }.to raise_error(/can only transition to complete from executing/)
      end
    end

    describe "#interrupt!" do
      it "transitions from executing to interrupted" do
        result.executing!
        result.interrupt!

        expect(result).to be_interrupted
      end

      it "transitions from initialized to interrupted" do
        result.interrupt!

        expect(result).to be_interrupted
      end

      it "is idempotent" do
        result.executing!
        result.interrupt!
        result.interrupt!

        expect(result).to be_interrupted
      end

      it "raises error when transitioning from complete" do
        result.executing!
        result.complete!

        expect { result.interrupt! }.to raise_error(/cannot transition to interrupted from complete/)
      end
    end
  end

  describe "status transitions" do
    describe "#skip!" do
      it "transitions from success to skipped" do
        result.skip!(original_exception: StandardError.new)

        expect(result).to be_skipped
      end

      it "stores metadata" do
        result.skip!(reason: "condition not met", original_exception: StandardError.new)

        expect(result).to have_metadata(reason: "condition not met")
      end

      it "is idempotent" do
        result.skip!(original_exception: StandardError.new)
        result.skip!(original_exception: StandardError.new)

        expect(result).to be_skipped
      end

      it "raises error when not transitioning from success" do
        result.fail!(original_exception: StandardError.new)

        expect { result.skip!(original_exception: StandardError.new) }.to raise_error(/can only transition to skipped from success/)
      end

      it "calls halt! unless original_exception in metadata" do
        expect(result).to receive(:halt!)

        result.skip!(reason: "test")
      end

      it "does not call halt! when original_exception in metadata" do
        expect(result).not_to receive(:halt!)

        result.skip!(original_exception: StandardError.new)
      end
    end

    describe "#fail!" do
      it "transitions from success to failed" do
        result.fail!(original_exception: StandardError.new)

        expect(result).to be_failed
      end

      it "stores metadata" do
        result.fail!(error: "validation failed", original_exception: StandardError.new)

        expect(result).to have_metadata(error: "validation failed")
      end

      it "is idempotent" do
        result.fail!(original_exception: StandardError.new)
        result.fail!(original_exception: StandardError.new)

        expect(result).to be_failed
      end

      it "raises error when not transitioning from success" do
        result.skip!(original_exception: StandardError.new)

        expect { result.fail!(original_exception: StandardError.new) }.to raise_error(/can only transition to failed from success/)
      end

      it "calls halt! unless original_exception in metadata" do
        expect(result).to receive(:halt!)

        result.fail!(error: "test")
      end

      it "does not call halt! when original_exception in metadata" do
        expect(result).not_to receive(:halt!)

        result.fail!(original_exception: StandardError.new)
      end
    end
  end

  describe "outcome methods" do
    describe "#good?" do
      it "returns true for success status" do
        expect(result).to have_good_outcome
      end

      it "returns true for skipped status" do
        result.skip!(original_exception: StandardError.new)

        expect(result).to have_good_outcome
      end

      it "returns false for failed status" do
        result.fail!(original_exception: StandardError.new)

        expect(result).not_to have_good_outcome
      end
    end

    describe "#bad?" do
      it "returns false for success status" do
        expect(result).not_to have_bad_outcome
      end

      it "returns true for skipped status" do
        result.skip!(original_exception: StandardError.new)

        expect(result).to have_bad_outcome
      end

      it "returns true for failed status" do
        result.fail!(original_exception: StandardError.new)

        expect(result).to have_bad_outcome
      end
    end

    describe "#executed?" do
      it "returns false for initialized state" do
        expect(result).not_to be_executed
      end

      it "returns false for executing state" do
        result.executing!

        expect(result).not_to be_executed
      end

      it "returns true for complete state" do
        result.executing!
        result.complete!

        expect(result).to be_executed
      end

      it "returns true for interrupted state" do
        result.executing!
        result.interrupt!

        expect(result).to be_executed
      end
    end

    describe "#executed!" do
      it "transitions to complete when status is success" do
        result.executing!
        result.executed!

        expect(result).to be_complete
      end

      it "transitions to interrupted when status is failed" do
        result.executing!
        result.fail!(original_exception: StandardError.new)
        result.executed!

        expect(result).to be_interrupted
      end

      it "transitions to interrupted when status is skipped" do
        result.executing!
        result.skip!(original_exception: StandardError.new)
        result.executed!

        expect(result).to be_interrupted
      end
    end
  end

  describe "callback methods" do
    describe "#on_initialized" do
      it "executes block when state is initialized" do
        executed = false
        result.on_initialized { executed = true }

        expect(executed).to be true
      end

      it "passes result to block" do
        passed_result = nil
        result.on_initialized { |r| passed_result = r }

        expect(passed_result).to eq(result)
      end

      it "does not execute block when state is not initialized" do
        result.executing!
        executed = false
        result.on_initialized { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_initialized { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_initialized }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_executing" do
      it "executes block when state is executing" do
        result.executing!
        executed = false
        result.on_executing { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when state is not executing" do
        executed = false
        result.on_executing { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_executing { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_executing }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_complete" do
      it "executes block when state is complete" do
        result.executing!
        result.complete!
        executed = false
        result.on_complete { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when state is not complete" do
        executed = false
        result.on_complete { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_complete { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_complete }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_interrupted" do
      it "executes block when state is interrupted" do
        result.executing!
        result.interrupt!
        executed = false
        result.on_interrupted { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when state is not interrupted" do
        executed = false
        result.on_interrupted { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_interrupted { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_interrupted }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_success" do
      it "executes block when status is success" do
        executed = false
        result.on_success { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when status is not success" do
        result.fail!(original_exception: StandardError.new)
        executed = false
        result.on_success { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_success { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_success }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_skipped" do
      it "executes block when status is skipped" do
        result.skip!(original_exception: StandardError.new)
        executed = false
        result.on_skipped { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when status is not skipped" do
        executed = false
        result.on_skipped { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_skipped { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_skipped }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_failed" do
      it "executes block when status is failed" do
        result.fail!(original_exception: StandardError.new)
        executed = false
        result.on_failed { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when status is not failed" do
        executed = false
        result.on_failed { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_failed { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_failed }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_good" do
      it "executes block when result is good" do
        executed = false
        result.on_good { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when result is not good" do
        result.fail!(original_exception: StandardError.new)
        executed = false
        result.on_good { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_good { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_good }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_bad" do
      it "executes block when result is bad" do
        result.skip!(original_exception: StandardError.new)
        executed = false
        result.on_bad { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when result is not bad" do
        executed = false
        result.on_bad { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_bad { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_bad }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#on_executed" do
      it "executes block when result is executed" do
        result.executing!
        result.complete!
        executed = false
        result.on_executed { executed = true }

        expect(executed).to be true
      end

      it "does not execute block when result is not executed" do
        executed = false
        result.on_executed { executed = true }

        expect(executed).to be false
      end

      it "returns self for method chaining" do
        expect(result.on_executed { nil }).to eq(result)
      end

      it "raises error when no block given" do
        expect { result.on_executed }.to raise_error(ArgumentError, "block required")
      end
    end
  end

  describe "#halt!" do
    it "does not raise when status is success" do
      expect { result.halt! }.not_to raise_error
    end

    it "raises Fault when status is failed" do
      result.fail!(original_exception: StandardError.new)

      expect { result.halt! }.to raise_error(CMDx::Fault)
    end

    it "raises Fault when status is skipped" do
      result.skip!(original_exception: StandardError.new)

      expect { result.halt! }.to raise_error(CMDx::Fault)
    end
  end

  describe "#throw!" do
    let(:other_task) { create_simple_task(name: "OtherTask").new }
    let(:other_result) { described_class.new(other_task) }

    it "raises TypeError for non-result" do
      expect { result.throw!("not a result") }.to raise_error(TypeError, "must be a Result")
    end

    it "propagates skipped status" do
      other_result.skip!(reason: "test", original_exception: StandardError.new)
      result.throw!(other_result)

      expect(result).to be_skipped
      expect(result).to have_metadata(reason: "test")
    end

    it "propagates failed status" do
      other_result.fail!(error: "test", original_exception: StandardError.new)
      result.throw!(other_result)

      expect(result).to be_failed
      expect(result).to have_metadata(error: "test")
    end

    it "merges local metadata" do
      other_result.fail!(error: "test", original_exception: StandardError.new)
      result.throw!(other_result, { local_error: "local" })

      expect(result).to have_metadata(error: "test", local_error: "local")
    end

    it "does not change status for successful result" do
      result.throw!(other_result)

      expect(result).to be_success
    end
  end

  describe "chain methods" do
    let(:task_one) { create_simple_task(name: "Task1").new }
    let(:task_two) { create_simple_task(name: "Task2").new }
    let(:result_one) { described_class.new(task_one) }
    let(:result_two) { described_class.new(task_two) }
    let(:chain) { double("chain") }

    before do
      allow(task).to receive(:chain).and_return(chain)
      allow(chain).to receive(:index).with(result).and_return(1)
      allow(chain).to receive(:results).and_return([result_one, result, result_two])
    end

    describe "#index" do
      it "returns index in chain" do
        expect(result.index).to eq(1)
      end
    end

    describe "#caused_failure" do
      it "returns nil when not failed" do
        expect(result.caused_failure).to be_nil
      end

      it "returns last failed result in chain" do
        result_one.fail!(original_exception: StandardError.new)
        result.fail!(original_exception: StandardError.new)
        allow(chain).to receive(:results).and_return([result_one, result])
        expect(result.caused_failure).to eq(result)
      end
    end

    describe "#caused_failure?" do
      it "returns false when not failed" do
        expect(result.caused_failure?).to be false
      end

      it "returns true when this is the original failure" do
        result.fail!(original_exception: StandardError.new)
        allow(result).to receive(:caused_failure).and_return(result)

        expect(result.caused_failure?).to be true
      end

      it "returns false when this is not the original failure" do
        result.fail!(original_exception: StandardError.new)
        allow(result).to receive(:caused_failure).and_return(result_one)

        expect(result.caused_failure?).to be false
      end
    end

    describe "#threw_failure" do
      it "returns nil when not failed" do
        expect(result.threw_failure).to be_nil
      end

      it "returns result that threw failure" do
        result.fail!(original_exception: StandardError.new)
        result_two.fail!(original_exception: StandardError.new)

        allow(chain).to receive(:results).and_return([result, result_two])
        allow(chain).to receive(:index).with(result).and_return(0)
        allow(chain).to receive(:index).with(result_two).and_return(1)
        allow(result_two).to receive(:index).and_return(1)
        expect(result.threw_failure).to eq(result_two)
      end
    end

    describe "#threw_failure?" do
      it "returns false when not failed" do
        expect(result.threw_failure?).to be false
      end

      it "returns true when this threw failure" do
        result.fail!(original_exception: StandardError.new)
        allow(result).to receive(:threw_failure).and_return(result)

        expect(result.threw_failure?).to be true
      end

      it "returns false when this did not throw failure" do
        result.fail!(original_exception: StandardError.new)
        allow(result).to receive(:threw_failure).and_return(result_one)

        expect(result.threw_failure?).to be false
      end
    end

    describe "#thrown_failure?" do
      it "returns false when not failed" do
        expect(result.thrown_failure?).to be false
      end

      it "returns true when failed but not original cause" do
        result.fail!(original_exception: StandardError.new)
        allow(result).to receive(:caused_failure?).and_return(false)

        expect(result.thrown_failure?).to be true
      end

      it "returns false when failed and original cause" do
        result.fail!(original_exception: StandardError.new)
        allow(result).to receive(:caused_failure?).and_return(true)

        expect(result.thrown_failure?).to be false
      end
    end
  end

  describe "#outcome" do
    it "returns state when initialized" do
      expect(result.outcome).to eq("initialized")
    end

    it "returns state when thrown failure" do
      result.fail!(original_exception: StandardError.new)
      allow(result).to receive(:thrown_failure?).and_return(true)

      expect(result.outcome).to eq("initialized")
    end

    it "returns status when not initialized and not thrown failure" do
      result.executing!
      expect(result.outcome).to eq("success")
    end
  end

  describe "#runtime" do
    it "returns nil when not measured" do
      expect(result.runtime).to be_nil
    end

    it "returns stored runtime" do
      result.instance_variable_set(:@runtime, 1.5)

      expect(result.runtime).to eq(1.5)
    end

    it "measures and stores runtime when block given" do
      expect(CMDx::Utils::MonotonicRuntime).to receive(:call).and_return(2.0)

      result.runtime { sleep 0.1 }

      expect(result.runtime).to eq(2.0)
    end
  end

  describe "#to_h" do
    it "delegates to ResultSerializer" do
      expect(CMDx::ResultSerializer).to receive(:call).with(result).and_return({ state: "initialized" })
      expect(result.to_h).to eq({ state: "initialized" })
    end
  end

  describe "#to_s" do
    it "delegates to ResultInspector" do
      allow(result).to receive(:to_h).and_return({ state: "initialized" })

      expect(CMDx::ResultInspector).to receive(:call).with({ state: "initialized" }).and_return("TestTask [initialized/success]")
      expect(result.to_s).to eq("TestTask [initialized/success]")
    end
  end

  describe "#deconstruct" do
    it "returns array of state and status" do
      expect(result.deconstruct).to eq(%w[initialized success])
    end
  end

  describe "#deconstruct_keys" do
    it "returns all attributes when keys is nil" do
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

    it "returns requested attributes when keys provided" do
      keys = result.deconstruct_keys(%i[state status])

      expect(keys).to eq(state: "initialized", status: "success")
    end
  end

  describe "delegated methods" do
    let(:mock_context) { double("context") }
    let(:mock_chain) { double("chain") }

    before do
      allow(task).to receive(:context).and_return(mock_context)
      allow(task).to receive(:chain).and_return(mock_chain)
    end

    it "delegates context to task" do
      expect(result.context).to eq(mock_context)
    end

    it "delegates chain to task" do
      expect(result.chain).to eq(mock_chain)
    end
  end

  describe "integration with task execution" do
    let(:successful_task) { create_simple_task(name: "SuccessfulTask") }
    let(:failing_task) { create_failing_task(name: "FailingTask", reason: "test error") }
    let(:skipping_task) { create_skipping_task(name: "SkippingTask", reason: "test skip") }

    it "creates successful task results" do
      result = successful_task.call

      expect(result).to be_successful_task
      expect(result).to have_empty_metadata
    end

    it "creates failed task results" do
      result = failing_task.call

      expect(result).to be_failed_task
      expect(result).to have_metadata(reason: "test error")
    end

    it "creates skipped task results" do
      result = skipping_task.call

      expect(result).to be_skipped
      expect(result).to have_metadata(reason: "test skip")
    end
  end

  describe "pattern matching" do
    it "supports array pattern matching" do
      matched = case result
                in ["initialized", "success"]
                  true
                else
                  false
                end

      expect(matched).to be true
    end

    it "supports hash pattern matching" do
      matched = case result
                in { state: "initialized", good: true }
                  true
                else
                  false
                end

      expect(matched).to be true
    end
  end
end

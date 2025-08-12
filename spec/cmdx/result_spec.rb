# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Result do
  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:task) { task_class.new }
  let(:result) { task.result }

  describe "#initialize" do
    it "initializes with valid task" do
      aggregate_failures do
        expect(result.task).to eq(task)
        expect(result.state).to eq(CMDx::Result::INITIALIZED)
        expect(result.status).to eq(CMDx::Result::SUCCESS)
        expect(result.metadata).to eq({})
        expect(result.reason).to be_nil
        expect(result.cause).to be_nil
      end
    end

    it "raises TypeError with invalid task" do
      expect { described_class.new("not a task") }.to raise_error(TypeError, "must be a CMDx::Task")
    end
  end

  describe "delegation" do
    it "delegates context to task" do
      expect(result.context).to eq(task.context)
    end

    it "delegates chain to task" do
      expect(result.chain).to eq(task.chain)
    end
  end

  describe "state predicate methods" do
    context "when initialized" do
      it "returns true for initialized?" do
        expect(result.initialized?).to be true
      end

      it "returns false for other state predicates" do
        aggregate_failures do
          expect(result.executing?).to be false
          expect(result.complete?).to be false
          expect(result.interrupted?).to be false
        end
      end
    end

    context "when executing" do
      before { result.executing! }

      it "returns true for executing?" do
        expect(result.executing?).to be true
      end

      it "returns false for other state predicates" do
        aggregate_failures do
          expect(result.initialized?).to be false
          expect(result.complete?).to be false
          expect(result.interrupted?).to be false
        end
      end
    end

    context "when complete" do
      before do
        result.executing!
        result.complete!
      end

      it "returns true for complete?" do
        expect(result.complete?).to be true
      end

      it "returns false for other state predicates" do
        aggregate_failures do
          expect(result.initialized?).to be false
          expect(result.executing?).to be false
          expect(result.interrupted?).to be false
        end
      end
    end

    context "when interrupted" do
      before { result.interrupt! }

      it "returns true for interrupted?" do
        expect(result.interrupted?).to be true
      end

      it "returns false for other state predicates" do
        aggregate_failures do
          expect(result.initialized?).to be false
          expect(result.executing?).to be false
          expect(result.complete?).to be false
        end
      end
    end
  end

  describe "handle_state methods" do
    let(:callback_result) { [] }

    CMDx::Result::STATES.each do |state|
      describe "#handle_#{state}" do
        it "executes block when in #{state} state" do
          result.instance_variable_set(:@state, state)

          result.send(:"handle_#{state}") { |r| callback_result << r }

          expect(callback_result).to contain_exactly(result)
        end

        it "does not execute block when not in #{state} state" do
          other_states = CMDx::Result::STATES - [state]
          result.instance_variable_set(:@state, other_states.first)

          result.send(:"handle_#{state}") { |r| callback_result << r }

          expect(callback_result).to be_empty
        end

        it "returns self" do
          expect(result.send(:"handle_#{state}") { |r| r }).to eq(result)
        end

        it "raises ArgumentError without block" do
          expect { result.send(:"handle_#{state}") }.to raise_error(ArgumentError, "block required")
        end
      end
    end
  end

  describe "#executed!" do
    context "when status is success" do
      before { result.executing! }

      it "transitions to complete state" do
        result.executed!
        expect(result.complete?).to be true
      end
    end

    context "when status is not success" do
      before do
        result.instance_variable_set(:@status, CMDx::Result::FAILED)
      end

      it "transitions to interrupted state" do
        result.executed!
        expect(result.interrupted?).to be true
      end
    end
  end

  describe "#executed?" do
    it "returns true when complete" do
      result.executing!
      result.complete!
      expect(result.executed?).to be true
    end

    it "returns true when interrupted" do
      result.interrupt!
      expect(result.executed?).to be true
    end

    it "returns false when not executed" do
      expect(result.executed?).to be false
    end
  end

  describe "#handle_executed" do
    let(:callback_result) { [] }

    it "executes block when executed" do
      result.interrupt!

      result.handle_executed { |r| callback_result << r }

      expect(callback_result).to contain_exactly(result)
    end

    it "does not execute block when not executed" do
      result.handle_executed { |r| callback_result << r }

      expect(callback_result).to be_empty
    end

    it "returns self" do
      expect(result.handle_executed { |r| r }).to eq(result)
    end

    it "raises ArgumentError without block" do
      expect { result.handle_executed }.to raise_error(ArgumentError, "block required")
    end
  end

  describe "state transition methods" do
    describe "#executing!" do
      it "transitions from initialized to executing" do
        result.executing!
        expect(result.executing?).to be true
      end

      it "is idempotent when already executing" do
        result.executing!
        expect { result.executing! }.not_to(change(result, :state))
      end

      it "raises error when not initialized" do
        result.interrupt!
        expect { result.executing! }.to raise_error("can only transition to executing from initialized")
      end
    end

    describe "#complete!" do
      before { result.executing! }

      it "transitions from executing to complete" do
        result.complete!
        expect(result.complete?).to be true
      end

      it "is idempotent when already complete" do
        result.complete!
        expect { result.complete! }.not_to(change(result, :state))
      end

      it "raises error when not executing" do
        result.interrupt!
        expect { result.complete! }.to raise_error("can only transition to complete from executing")
      end
    end

    describe "#interrupt!" do
      it "transitions from initialized to interrupted" do
        result.interrupt!
        expect(result.interrupted?).to be true
      end

      it "transitions from executing to interrupted" do
        result.executing!
        result.interrupt!
        expect(result.interrupted?).to be true
      end

      it "is idempotent when already interrupted" do
        result.interrupt!
        expect { result.interrupt! }.not_to(change(result, :state))
      end

      it "raises error when complete" do
        result.executing!
        result.complete!
        expect { result.interrupt! }.to raise_error("cannot transition to interrupted from complete")
      end
    end
  end

  describe "status predicate methods" do
    CMDx::Result::STATUSES.each do |status|
      describe "##{status}?" do
        it "returns true when status matches" do
          result.instance_variable_set(:@status, status)
          expect(result.send(:"#{status}?")).to be true
        end

        it "returns false when status does not match" do
          other_statuses = CMDx::Result::STATUSES - [status]
          result.instance_variable_set(:@status, other_statuses.first)
          expect(result.send(:"#{status}?")).to be false
        end
      end
    end
  end

  describe "handle_status methods" do
    let(:callback_result) { [] }

    CMDx::Result::STATUSES.each do |status|
      describe "#handle_#{status}" do
        it "executes block when in #{status} status" do
          result.instance_variable_set(:@status, status)

          result.send(:"handle_#{status}") { |r| callback_result << r }

          expect(callback_result).to contain_exactly(result)
        end

        it "does not execute block when not in #{status} status" do
          other_statuses = CMDx::Result::STATUSES - [status]
          result.instance_variable_set(:@status, other_statuses.first)

          result.send(:"handle_#{status}") { |r| callback_result << r }

          expect(callback_result).to be_empty
        end

        it "returns self" do
          expect(result.send(:"handle_#{status}") { |r| r }).to eq(result)
        end

        it "raises ArgumentError without block" do
          expect { result.send(:"handle_#{status}") }.to raise_error(ArgumentError, "block required")
        end
      end
    end
  end

  describe "#good?" do
    it "returns true when not failed" do
      expect(result.good?).to be true
    end

    it "returns false when failed" do
      result.instance_variable_set(:@status, CMDx::Result::FAILED)
      expect(result.good?).to be false
    end
  end

  describe "#handle_good" do
    let(:callback_result) { [] }

    it "executes block when good" do
      result.handle_good { |r| callback_result << r }
      expect(callback_result).to contain_exactly(result)
    end

    it "does not execute block when not good" do
      result.instance_variable_set(:@status, CMDx::Result::FAILED)
      result.handle_good { |r| callback_result << r }
      expect(callback_result).to be_empty
    end

    it "returns self" do
      expect(result.handle_good { |r| r }).to eq(result)
    end

    it "raises ArgumentError without block" do
      expect { result.handle_good }.to raise_error(ArgumentError, "block required")
    end
  end

  describe "#bad?" do
    it "returns false when success" do
      expect(result.bad?).to be false
    end

    it "returns true when not success" do
      result.instance_variable_set(:@status, CMDx::Result::FAILED)
      expect(result.bad?).to be true
    end
  end

  describe "#handle_bad" do
    let(:callback_result) { [] }

    it "executes block when bad" do
      result.instance_variable_set(:@status, CMDx::Result::FAILED)
      result.handle_bad { |r| callback_result << r }
      expect(callback_result).to contain_exactly(result)
    end

    it "does not execute block when not bad" do
      result.handle_bad { |r| callback_result << r }
      expect(callback_result).to be_empty
    end

    it "returns self" do
      expect(result.handle_bad { |r| r }).to eq(result)
    end

    it "raises ArgumentError without block" do
      expect { result.handle_bad }.to raise_error(ArgumentError, "block required")
    end
  end

  describe "#skip!" do
    let(:reason) { "test reason" }
    let(:metadata) { { key: "value" } }
    let(:cause) { StandardError.new("test cause") }

    it "transitions to skipped status" do
      result.skip!(reason, halt: false, **metadata, cause: cause)

      aggregate_failures do
        expect(result.interrupted?).to be true
        expect(result.skipped?).to be true
        expect(result.reason).to eq(reason)
        expect(result.cause).to eq(cause)
        expect(result.metadata).to eq(metadata)
      end
    end

    it "uses default reason when none provided" do
      allow(CMDx::Locale).to receive(:t).with("cmdx.faults.unspecified").and_return("default reason")

      result.skip!(halt: false)

      expect(result.reason).to eq("default reason")
    end

    it "is idempotent when already skipped" do
      result.skip!(reason, halt: false)
      expect { result.skip!("new reason", halt: false) }.not_to(change { [result.state, result.status, result.reason] })
    end

    it "raises error when not success status" do
      result.instance_variable_set(:@status, CMDx::Result::FAILED)
      expect { result.skip!(halt: false) }.to raise_error("can only transition to skipped from success")
    end

    context "with halt: false" do
      it "does not call halt!" do
        allow(result).to receive(:halt!)
        result.skip!(halt: false)
        expect(result).not_to have_received(:halt!)
      end
    end

    context "with halt: true" do
      it "raises SkipFault" do
        expect { result.skip! }.to raise_error(CMDx::SkipFault)
      end
    end
  end

  describe "#fail!" do
    let(:reason) { "test reason" }
    let(:metadata) { { key: "value" } }
    let(:cause) { StandardError.new("test cause") }

    it "transitions to failed status" do
      result.fail!(reason, halt: false, **metadata, cause: cause)

      aggregate_failures do
        expect(result.interrupted?).to be true
        expect(result.failed?).to be true
        expect(result.reason).to eq(reason)
        expect(result.cause).to eq(cause)
        expect(result.metadata).to eq(metadata)
      end
    end

    it "uses default reason when none provided" do
      allow(CMDx::Locale).to receive(:t).with("cmdx.faults.unspecified").and_return("default reason")

      result.fail!(halt: false)

      expect(result.reason).to eq("default reason")
    end

    it "is idempotent when already failed" do
      result.fail!(reason, halt: false)
      expect { result.fail!("new reason", halt: false) }.not_to(change { [result.state, result.status, result.reason] })
    end

    it "raises error when not success status" do
      result.instance_variable_set(:@status, CMDx::Result::SKIPPED)
      expect { result.fail!(halt: false) }.to raise_error("can only transition to failed from success")
    end

    context "with halt: false" do
      it "does not call halt!" do
        allow(result).to receive(:halt!)
        result.fail!(halt: false)
        expect(result).not_to have_received(:halt!)
      end
    end

    context "with halt: true" do
      it "raises FailFault" do
        expect { result.fail! }.to raise_error(CMDx::FailFault)
      end
    end
  end

  describe "#halt!" do
    context "when success" do
      it "returns without raising" do
        expect { result.halt! }.not_to raise_error
      end
    end

    context "when skipped" do
      before { result.skip!(halt: false) }

      it "raises SkipFault" do
        expect { result.halt! }.to raise_error(CMDx::SkipFault)
      end

      it "sets backtrace on fault" do
        result.halt!
      rescue CMDx::SkipFault => e
        expect(e.backtrace).not_to be_empty
      end
    end

    context "when failed" do
      before { result.fail!(halt: false) }

      it "raises FailFault" do
        expect { result.halt! }.to raise_error(CMDx::FailFault)
      end

      it "sets backtrace on fault" do
        result.halt!
      rescue CMDx::FailFault => e
        expect(e.backtrace).not_to be_empty
      end
    end
  end

  describe "#throw!" do
    let(:other_task) { task_class.new }
    let(:other_result) { other_task.result }
    let(:metadata) { { key: "value" } }
    let(:cause) { StandardError.new("test cause") }

    before do
      other_result.fail!("other reason", halt: false, **metadata)
    end

    it "copies state from other result" do
      result.throw!(other_result, halt: false)

      aggregate_failures do
        expect(result.state).to eq(other_result.state)
        expect(result.status).to eq(other_result.status)
        expect(result.reason).to eq(other_result.reason)
      end
    end

    it "merges metadata" do
      result.throw!(other_result, halt: false, extra: "data")

      expect(result.metadata).to include(metadata.merge(extra: "data"))
    end

    it "uses provided cause or copies from other result" do
      result.throw!(other_result, halt: false, cause: cause)
      expect(result.cause).to eq(cause)
    end

    it "copies cause from other result when none provided" do
      result.throw!(other_result, halt: false)
      expect(result.cause).to eq(other_result.cause)
    end

    it "raises TypeError with invalid result" do
      expect { result.throw!("not a result") }.to raise_error(TypeError, "must be a CMDx::Result")
    end

    context "with halt: false" do
      it "does not call halt!" do
        allow(result).to receive(:halt!)
        result.throw!(other_result, halt: false)
        expect(result).not_to have_received(:halt!)
      end
    end

    context "with halt: true" do
      it "calls halt!" do
        allow(result).to receive(:halt!)
        result.throw!(other_result)
        expect(result).to have_received(:halt!)
      end
    end
  end

  describe "failure detection methods" do
    let(:chain) { instance_double(CMDx::Chain) }
    let(:failed_result1) { instance_double(described_class, failed?: true, index: 1) }
    let(:failed_result2) { instance_double(described_class, failed?: true, index: 3) }
    let(:success_result) { instance_double(described_class, failed?: false) }

    before do
      allow(result).to receive_messages(chain: chain, index: 2)
      result.instance_variable_set(:@status, CMDx::Result::FAILED)
    end

    describe "#caused_failure" do
      it "returns first failed result in reverse order when failed" do
        chain_results = [success_result, failed_result1, result, failed_result2]
        allow(chain).to receive(:results).and_return(chain_results)

        expect(result.caused_failure).to be_a(RSpec::Mocks::InstanceVerifyingDouble)
        expect(result.caused_failure.failed?).to be true
      end

      it "returns nil when not failed" do
        result.instance_variable_set(:@status, CMDx::Result::SUCCESS)

        expect(result.caused_failure).to be_nil
      end
    end

    describe "#caused_failure?" do
      it "returns true when this result is the caused failure" do
        allow(result).to receive(:caused_failure).and_return(result)

        expect(result.caused_failure?).to be true
      end

      it "returns false when this result is not the caused failure" do
        allow(result).to receive(:caused_failure).and_return(failed_result1)

        expect(result.caused_failure?).to be false
      end

      it "returns false when not failed" do
        result.instance_variable_set(:@status, CMDx::Result::SUCCESS)

        expect(result.caused_failure?).to be false
      end
    end

    describe "#threw_failure" do
      it "returns next failed result with higher index" do
        failed_results = [failed_result1, result, failed_result2]
        allow(chain).to receive(:results).and_return([success_result] + failed_results)
        allow(chain.results).to receive(:select).and_return(failed_results)

        expect(result.threw_failure).to eq(failed_result2)
      end

      it "returns last failed result when no higher index found" do
        failed_results = [failed_result1, result]
        allow(chain).to receive(:results).and_return([success_result] + failed_results)
        allow(chain.results).to receive(:select).and_return(failed_results)

        expect(result.threw_failure).to eq(result)
      end

      it "returns nil when not failed" do
        result.instance_variable_set(:@status, CMDx::Result::SUCCESS)

        expect(result.threw_failure).to be_nil
      end
    end

    describe "#threw_failure?" do
      it "returns true when this result is the threw failure" do
        allow(result).to receive(:threw_failure).and_return(result)

        expect(result.threw_failure?).to be true
      end

      it "returns false when this result is not the threw failure" do
        allow(result).to receive(:threw_failure).and_return(failed_result2)

        expect(result.threw_failure?).to be false
      end

      it "returns false when not failed" do
        result.instance_variable_set(:@status, CMDx::Result::SUCCESS)

        expect(result.threw_failure?).to be false
      end
    end

    describe "#thrown_failure?" do
      it "returns true when failed and not caused failure" do
        allow(result).to receive(:caused_failure?).and_return(false)

        expect(result.thrown_failure?).to be true
      end

      it "returns false when not failed" do
        result.instance_variable_set(:@status, CMDx::Result::SUCCESS)

        expect(result.thrown_failure?).to be false
      end

      it "returns false when failed but is caused failure" do
        allow(result).to receive(:caused_failure?).and_return(true)

        expect(result.thrown_failure?).to be false
      end
    end
  end

  describe "#index" do
    it "delegates to chain.index" do
      chain = instance_double(CMDx::Chain)
      allow(result).to receive(:chain).and_return(chain)
      allow(chain).to receive(:index).with(result).and_return(42)

      expect(result.index).to eq(42)
    end
  end

  describe "#outcome" do
    it "returns state when initialized" do
      expect(result.outcome).to eq(CMDx::Result::INITIALIZED)
    end

    it "returns state when thrown failure" do
      result.instance_variable_set(:@status, CMDx::Result::FAILED)
      allow(result).to receive(:thrown_failure?).and_return(true)

      expect(result.outcome).to eq(CMDx::Result::INITIALIZED)
    end

    it "returns status when not initialized and not thrown failure" do
      result.executing!

      expect(result.outcome).to eq(CMDx::Result::SUCCESS)
    end
  end

  describe "#to_h" do
    let(:task_hash) { { type: "Task", class: "TestTask", id: "test-id" } }

    before do
      allow(task).to receive(:to_h).and_return(task_hash)
    end

    it "includes basic result data" do
      hash = result.to_h

      expect(hash).to include(
        state: CMDx::Result::INITIALIZED,
        status: CMDx::Result::SUCCESS,
        outcome: CMDx::Result::INITIALIZED,
        metadata: {}
      )
    end

    it "merges task data" do
      hash = result.to_h

      expect(hash).to include(task_hash)
    end

    context "when interrupted" do
      before { result.skip!("test reason", halt: false, cause: "test cause") }

      it "includes reason and cause" do
        hash = result.to_h

        expect(hash).to include(
          reason: "test reason",
          cause: "test cause"
        )
      end
    end

    context "when failed" do
      let(:threw_failure_hash) { { index: 1, class: "FailedTask", id: "failed-id" } }
      let(:caused_failure_hash) { { index: 0, class: "CausedTask", id: "caused-id" } }

      before do
        result.fail!("test failure", halt: false)
      end

      it "strips failure data when not threw_failure" do
        threw_failure = instance_double(described_class)
        allow(threw_failure).to receive(:to_h).and_return(threw_failure_hash.merge(caused_failure: {}, threw_failure: {}))
        allow(result).to receive_messages(threw_failure?: false, threw_failure: threw_failure)

        hash = result.to_h

        expect(hash[:threw_failure]).to eq(threw_failure_hash)
      end

      it "strips failure data when not caused_failure" do
        caused_failure = instance_double(described_class)
        allow(caused_failure).to receive(:to_h).and_return(caused_failure_hash.merge(caused_failure: {}, threw_failure: {}))
        allow(result).to receive_messages(caused_failure?: false, caused_failure: caused_failure)

        hash = result.to_h

        expect(hash[:caused_failure]).to eq(caused_failure_hash)
      end
    end
  end

  describe "#to_s" do
    it "formats result as string" do
      allow(CMDx::Utils::Format).to receive(:to_str).and_return("formatted string")

      result_string = result.to_s

      expect(result_string).to eq("formatted string")
      expect(CMDx::Utils::Format).to have_received(:to_str).with(hash_including(:state, :status))
    end
  end

  describe "#deconstruct" do
    it "returns state and status as array" do
      expect(result.deconstruct).to eq([CMDx::Result::INITIALIZED, CMDx::Result::SUCCESS])
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash with key result data" do
      expected_keys = {
        state: CMDx::Result::INITIALIZED,
        status: CMDx::Result::SUCCESS,
        metadata: {},
        executed: false,
        good: true,
        bad: false
      }

      expect(result.deconstruct_keys).to eq(expected_keys)
    end
  end
end

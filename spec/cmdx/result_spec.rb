# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Result, type: :unit do
  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:task) { task_class.new }
  let(:result) { task.result }
  let(:resolver) { task.resolver }

  describe "#initialize" do
    context "with valid task" do
      it "initializes with correct defaults" do
        expect(result.task).to eq(task)
        expect(result.state).to eq(CMDx::Result::INITIALIZED)
        expect(result.status).to eq(CMDx::Result::SUCCESS)
        expect(result.metadata).to eq({})
        expect(result.reason).to be_nil
        expect(result.cause).to be_nil
      end

      it "delegates context and chain to task" do
        expect(result.context).to eq(task.context)
        expect(result.chain).to eq(task.chain)
      end
    end

    context "with invalid task" do
      it "raises TypeError when task is not a CMDx::Task" do
        expect { described_class.new("not a task") }.to raise_error(TypeError, "must be a CMDx::Task")
      end
    end
  end

  describe "state predicates" do
    describe "#initialized?" do
      it "returns true when state is initialized" do
        expect(result.initialized?).to be(true)
      end

      it "returns false when state is not initialized" do
        resolver.executing!

        expect(result.initialized?).to be(false)
      end
    end

    describe "#executing?" do
      it "returns false when state is initialized" do
        expect(result.executing?).to be(false)
      end

      it "returns true when state is executing" do
        resolver.executing!

        expect(result.executing?).to be(true)
      end
    end

    describe "#complete?" do
      it "returns false when state is not complete" do
        expect(result.complete?).to be(false)
      end

      it "returns true when state is complete" do
        resolver.executing!
        resolver.complete!

        expect(result.complete?).to be(true)
      end
    end

    describe "#interrupted?" do
      it "returns false when state is not interrupted" do
        expect(result.interrupted?).to be(false)
      end

      it "returns true when state is interrupted" do
        resolver.executing!
        resolver.interrupt!

        expect(result.interrupted?).to be(true)
      end
    end
  end

  describe "state transitions" do
    describe "#executing!" do
      context "when initialized" do
        it "transitions to executing state" do
          resolver.executing!

          expect(result.state).to eq(CMDx::Result::EXECUTING)
        end

        it "returns early if already executing" do
          resolver.executing!
          initial_state = result.state
          resolver.executing!

          expect(result.state).to eq(initial_state)
        end
      end

      context "when not initialized" do
        it "raises error when trying to transition from complete" do
          resolver.executing!
          resolver.complete!

          expect { resolver.executing! }.to raise_error(/can only transition to executing from initialized/)
        end

        it "raises error when trying to transition from interrupted" do
          resolver.executing!
          resolver.interrupt!

          expect { resolver.executing! }.to raise_error(/can only transition to executing from initialized/)
        end
      end
    end

    describe "#complete!" do
      context "when executing" do
        before { resolver.executing! }

        it "transitions to complete state" do
          resolver.complete!

          expect(result.state).to eq(CMDx::Result::COMPLETE)
        end

        it "returns early if already complete" do
          resolver.complete!
          initial_state = result.state
          resolver.complete!

          expect(result.state).to eq(initial_state)
        end
      end

      context "when not executing" do
        it "raises error when trying to transition from initialized" do
          expect { resolver.complete! }.to raise_error(/can only transition to complete from executing/)
        end
      end
    end

    describe "#interrupt!" do
      context "when not complete" do
        it "transitions to interrupted from initialized" do
          resolver.interrupt!

          expect(result.state).to eq(CMDx::Result::INTERRUPTED)
        end

        it "transitions to interrupted from executing" do
          resolver.executing!
          resolver.interrupt!

          expect(result.state).to eq(CMDx::Result::INTERRUPTED)
        end

        it "returns early if already interrupted" do
          resolver.interrupt!
          initial_state = result.state
          resolver.interrupt!

          expect(result.state).to eq(initial_state)
        end
      end

      context "when complete" do
        it "raises error when trying to transition from complete" do
          resolver.executing!
          resolver.complete!

          expect { resolver.interrupt! }.to raise_error(/cannot transition to interrupted from complete/)
        end
      end
    end
  end

  describe "status predicates" do
    describe "#success?" do
      it "returns true by default" do
        expect(result.success?).to be(true)
      end

      it "returns false after skip!" do
        resolver.skip!("test reason", halt: false)

        expect(result.success?).to be(false)
      end

      it "returns false after fail!" do
        resolver.fail!("test reason", halt: false)

        expect(result.success?).to be(false)
      end
    end

    describe "#skipped?" do
      it "returns false by default" do
        expect(result.skipped?).to be(false)
      end

      it "returns true after skip!" do
        resolver.skip!("test reason", halt: false)

        expect(result.skipped?).to be(true)
      end
    end

    describe "#failed?" do
      it "returns false by default" do
        expect(result.failed?).to be(false)
      end

      it "returns true after fail!" do
        resolver.fail!("test reason", halt: false)

        expect(result.failed?).to be(true)
      end
    end

    describe "#good?" do
      it "returns true when not failed" do
        expect(result.good?).to be(true)
      end

      it "returns true when skipped" do
        resolver.skip!("test reason", halt: false)

        expect(result.good?).to be(true)
      end

      it "returns false when failed" do
        resolver.fail!("test reason", halt: false)

        expect(result.good?).to be(false)
      end
    end

    describe "#bad?" do
      it "returns false when successful" do
        expect(result.bad?).to be(false)
      end

      it "returns true when skipped" do
        resolver.skip!("test reason", halt: false)

        expect(result.bad?).to be(true)
      end

      it "returns true when failed" do
        resolver.fail!("test reason", halt: false)

        expect(result.bad?).to be(true)
      end
    end

    describe "#rolled_back?" do
      it "returns false by default" do
        expect(result.rolled_back?).to be(false)
      end

      it "returns true when rolled back" do
        result.rolled_back = true

        expect(result.rolled_back?).to be(true)
      end
    end

    describe "#retried?" do
      it "returns false when retries is zero" do
        expect(result.retried?).to be(false)
      end

      it "returns true when retries is positive" do
        result.retries = 1

        expect(result.retried?).to be(true)
      end
    end
  end

  describe "execution methods" do
    describe "#executed!" do
      context "when successful" do
        it "calls complete!" do
          resolver.executing!
          resolver.executed!

          expect(result.complete?).to be(true)
        end
      end

      context "when not successful" do
        it "calls interrupt! when skipped" do
          resolver.skip!("test reason", halt: false)
          resolver.executed!

          expect(result.interrupted?).to be(true)
        end

        it "calls interrupt! when failed" do
          resolver.fail!("test reason", halt: false)
          resolver.executed!

          expect(result.interrupted?).to be(true)
        end
      end
    end

    describe "#executed?" do
      it "returns false when not executed" do
        expect(result.executed?).to be(false)
      end

      it "returns true when complete" do
        resolver.executing!
        resolver.complete!

        expect(result.executed?).to be(true)
      end

      it "returns true when interrupted" do
        resolver.interrupt!

        expect(result.executed?).to be(true)
      end
    end

    describe "#on(:executed)" do
      it "raises ArgumentError without block" do
        expect { result.on(:executed) }.to raise_error(ArgumentError, "block required")
      end

      it "calls block when executed" do
        resolver.interrupt!
        called = false
        result.on(:executed) { |_r| called = true }

        expect(called).to be(true)
      end

      it "does not call block when not executed" do
        called = false
        result.on(:executed) { |_r| called = true }

        expect(called).to be(false)
      end

      it "returns self" do
        expect(result.on(:executed) { "test" }).to eq(result)
      end
    end
  end

  describe "failure tracking methods" do
    let(:chain) { CMDx::Chain.new }
    let(:first_task) { create_successful_task.new }
    let(:second_task) { create_failing_task.new }
    let(:third_task) { create_successful_task.new }
    let(:first_result) { first_task.result }
    let(:second_result) { second_task.result }
    let(:third_result) { third_task.result }

    before do
      chain.results.push(first_result, second_result, third_result)

      [first_result, second_result, third_result].each do |r|
        r.instance_variable_set(:@chain, chain)
      end

      second_task.resolver.fail!("test failure", halt: false)
    end

    describe "#caused_failure" do
      context "when failed" do
        it "returns the first failed result in chain" do
          expect(second_result.caused_failure).to eq(second_result)
        end
      end

      context "when not failed" do
        it "returns nil" do
          expect(first_result.caused_failure).to be_nil
        end
      end
    end

    describe "#caused_failure?" do
      it "returns true for the causing failure" do
        expect(second_result.caused_failure?).to be(true)
      end

      it "returns false for non-failing results" do
        expect(first_result.caused_failure?).to be(false)
      end

      it "returns false for non-failed results" do
        expect(third_result.caused_failure?).to be(false)
      end
    end

    describe "#threw_failure" do
      context "when failed" do
        let(:fourth_task) { create_failing_task.new }
        let(:fourth_result) { fourth_task.result }

        before do
          chain.results << fourth_result

          fourth_result.instance_variable_set(:@chain, chain)
          fourth_task.resolver.fail!("another failure", halt: false)
        end

        it "returns the next failed result after current" do
          expect(second_result.threw_failure).to eq(fourth_result)
        end

        it "returns the last failed result when no failures after current" do
          expect(fourth_result.threw_failure).to eq(fourth_result)
        end
      end

      context "when not failed" do
        it "returns nil" do
          expect(first_result.threw_failure).to be_nil
        end
      end
    end

    describe "#threw_failure?" do
      it "returns true when the result is the last failure" do
        expect(second_result.threw_failure?).to be(true)
      end

      it "returns false for non-failing results" do
        expect(first_result.threw_failure?).to be(false)
      end
    end

    describe "#thrown_failure?" do
      it "returns false when result caused the failure" do
        expect(second_result.thrown_failure?).to be(false)
      end

      it "returns false for non-failed results" do
        expect(first_result.thrown_failure?).to be(false)
      end
    end
  end

  describe "#index" do
    it "returns the cached chain index set during push" do
      expect(result.index).to eq(0)
    end

    it "falls back to chain.index when cache is not set" do
      result.remove_instance_variable(:@chain_index) if result.instance_variable_defined?(:@chain_index)
      allow(result.chain).to receive(:index).with(result).and_return(42)

      expect(result.index).to eq(42)
    end
  end

  describe "#outcome" do
    context "when initialized" do
      it "returns state" do
        expect(result.outcome).to eq(result.state)
      end
    end

    context "when thrown failure" do
      it "returns state" do
        allow(result).to receive(:thrown_failure?).and_return(true)

        expect(result.outcome).to eq(result.state)
      end
    end

    context "when not initialized and not thrown failure" do
      it "returns status" do
        resolver.executing!

        expect(result.outcome).to eq(result.status)
      end
    end
  end

  describe "#to_h" do
    it "includes basic task and result information" do
      hash = result.to_h
      task_hash = task.to_h

      expect(hash).to include(
        state: result.state,
        status: result.status,
        outcome: result.outcome,
        metadata: result.metadata,
        index: task_hash[:index],
        chain_id: task_hash[:chain_id],
        type: task_hash[:type],
        tags: task_hash[:tags],
        id: task_hash[:id],
        class: start_with("TestTask")
      )
    end

    context "when successful with reason" do
      it "includes reason without cause or rolled_back" do
        catch(:cmdx_halt) { resolver.success!("Created 42 records") }

        hash = result.to_h

        expect(hash[:reason]).to eq("Created 42 records")
        expect(hash).not_to include(:cause, :rolled_back)
      end
    end

    context "when interrupted" do
      it "includes reason, cause and rolled_back status" do
        resolver.skip!("test reason", halt: false, cause: StandardError.new("test"))

        hash = result.to_h

        expect(hash).to include(:reason, :cause, :rolled_back)
        expect(hash[:reason]).to eq("test reason")
        expect(hash[:rolled_back]).to be(false)
      end
    end

    context "when failed" do
      it "includes failure information" do
        resolver.fail!("test failure", halt: false)

        # Create mock objects that avoid calling to_h to prevent infinite recursion
        threw_failure_mock = instance_double(described_class, to_h: { index: 1, class: "Test", id: "123" })
        caused_failure_mock = instance_double(described_class, to_h: { index: 0, class: "Test", id: "456" })

        allow(result).to receive_messages(threw_failure?: false, caused_failure?: false, threw_failure: threw_failure_mock, caused_failure: caused_failure_mock)

        hash = result.to_h

        expect(hash).to include(:threw_failure, :caused_failure)
        expect(hash[:threw_failure]).to eq({ index: 1, class: "Test", id: "123" })
        expect(hash[:caused_failure]).to eq({ index: 0, class: "Test", id: "456" })
      end
    end
  end

  describe "#to_s" do
    it "formats hash using Utils::Format.to_str" do
      expect(CMDx::Utils::Format).to receive(:to_str).and_return("formatted string")

      expect(result.to_s).to eq("formatted string")
    end

    it "handles failure formatting in block" do
      expect(CMDx::Utils::Format).to receive(:to_str).and_return("formatted string")

      result.to_s
    end
  end

  describe "#deconstruct" do
    it "returns state and status as array" do
      expect(result.deconstruct).to eq(
        [
          result.state,
          result.status,
          result.reason,
          result.cause,
          result.metadata
        ]
      )
    end

    it "ignores arguments" do
      expect(result.deconstruct(:anything, :here)).to eq(
        [
          result.state,
          result.status,
          result.reason,
          result.cause,
          result.metadata
        ]
      )
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash with key attributes" do
      expected = {
        state: result.state,
        status: result.status,
        reason: result.reason,
        cause: result.cause,
        metadata: result.metadata,
        outcome: result.outcome,
        executed: result.executed?,
        good: result.good?,
        bad: result.bad?
      }

      expect(result.deconstruct_keys).to eq(expected)
    end

    it "ignores arguments" do
      expected = result.deconstruct_keys

      expect(result.deconstruct_keys(:anything)).to eq(expected)
    end
  end

  describe "handle methods" do
    describe "state handle methods" do
      CMDx::Result::STATES.each do |state|
        describe "#on(#{state})" do
          it "raises ArgumentError without block" do
            expect { result.on(state) }.to raise_error(ArgumentError, "block required")
          end

          context "when in #{state} state" do
            before do
              case state
              when CMDx::Result::INITIALIZED
                # Already in initialized state
              when CMDx::Result::EXECUTING
                resolver.executing!
              when CMDx::Result::COMPLETE
                resolver.executing!
                resolver.complete!
              when CMDx::Result::INTERRUPTED
                resolver.interrupt!
              end
            end

            it "calls the block" do
              called = false
              result.on(state) { |_r| called = true }

              expect(called).to be(true)
            end

            it "passes result to block" do
              block_result = nil
              result.on(state) { |r| block_result = r }

              expect(block_result).to eq(result)
            end
          end

          context "when not in #{state} state" do
            before do
              case state
              when CMDx::Result::INITIALIZED
                resolver.executing!
              when CMDx::Result::EXECUTING
                # Stay in initialized state
              when CMDx::Result::COMPLETE
                # Stay in initialized state
              when CMDx::Result::INTERRUPTED
                # Stay in initialized state
              end
            end

            it "does not call the block" do
              called = false
              result.on(state) { |_r| called = true }

              expect(called).to be(false)
            end
          end

          it "returns self" do
            expect(result.on(state) { "test" }).to eq(result)
          end
        end
      end
    end

    describe "status handle methods" do
      CMDx::Result::STATUSES.each do |status|
        describe "#on(#{status})" do
          it "raises ArgumentError without block" do
            expect { result.on(status) }.to raise_error(ArgumentError, "block required")
          end

          context "when in #{status} status" do
            before do
              case status
              when CMDx::Result::SUCCESS
                # Already in success status
              when CMDx::Result::SKIPPED
                resolver.skip!("test", halt: false)
              when CMDx::Result::FAILED
                resolver.fail!("test", halt: false)
              end
            end

            it "calls the block" do
              called = false
              result.on(status) { |_r| called = true }

              expect(called).to be(true)
            end

            it "passes result to block" do
              block_result = nil
              result.on(status) { |r| block_result = r }

              expect(block_result).to eq(result)
            end
          end

          context "when not in #{status} status" do
            before do
              case status
              when CMDx::Result::SUCCESS
                resolver.skip!("test", halt: false)
              when CMDx::Result::SKIPPED
                # Stay in success status
              when CMDx::Result::FAILED
                # Stay in success status
              end
            end

            it "does not call the block" do
              called = false
              result.on(status) { |_r| called = true }

              expect(called).to be(false)
            end
          end

          it "returns self" do
            expect(result.on(status) { "test" }).to eq(result)
          end
        end
      end
    end

    describe "#on(:good)" do
      it "raises ArgumentError without block" do
        expect { result.on(:good) }.to raise_error(ArgumentError, "block required")
      end

      context "when good" do
        it "calls the block for success" do
          called = false
          result.on(:good) { |_r| called = true }

          expect(called).to be(true)
        end

        it "calls the block for skipped" do
          resolver.skip!("test", halt: false)
          called = false
          result.on(:good) { |_r| called = true }

          expect(called).to be(true)
        end
      end

      context "when not good" do
        it "does not call the block for failed" do
          resolver.fail!("test", halt: false)
          called = false
          result.on(:good) { |_r| called = true }

          expect(called).to be(false)
        end
      end

      it "returns self" do
        expect(result.on(:good) { "test" }).to eq(result)
      end
    end

    describe "#on(:bad)" do
      it "raises ArgumentError without block" do
        expect { result.on(:bad) }.to raise_error(ArgumentError, "block required")
      end

      context "when bad" do
        it "calls the block for skipped" do
          resolver.skip!("test", halt: false)
          called = false
          result.on(:bad) { |_r| called = true }

          expect(called).to be(true)
        end

        it "calls the block for failed" do
          resolver.fail!("test", halt: false)
          called = false
          result.on(:bad) { |_r| called = true }

          expect(called).to be(true)
        end
      end

      context "when not bad" do
        it "does not call the block for success" do
          called = false
          result.on(:bad) { |_r| called = true }

          expect(called).to be(false)
        end
      end

      it "returns self" do
        expect(result.on(:bad) { "test" }).to eq(result)
      end
    end
  end

  describe "constants" do
    describe "STATES" do
      it "defines all expected states" do
        expect(CMDx::Result::STATES).to contain_exactly(
          "initialized",
          "executing",
          "complete",
          "interrupted"
        )
      end

      it "freezes the array" do
        expect(CMDx::Result::STATES).to be_frozen
      end
    end

    describe "STATUSES" do
      it "defines all expected statuses" do
        expect(CMDx::Result::STATUSES).to contain_exactly(
          "success",
          "skipped",
          "failed"
        )
      end

      it "freezes the array" do
        expect(CMDx::Result::STATUSES).to be_frozen
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Result do
  subject(:result) { SimulationTask.call(simulate:) }

  let(:simulate) { :success }
  let(:initialized_result) { described_class.new(initialized_task) }
  let(:initialized_task) { SimulationTask.send(:new) }

  describe "#initialize" do
    it "returns initialized" do
      expect(initialized_result.state).to eq(CMDx::Result::INITIALIZED)
      expect(initialized_result.status).to eq(CMDx::Result::SUCCESS)
    end
  end

  describe "state predicate methods" do
    context "when initialized" do
      subject(:result) { initialized_result }

      it_behaves_like "result state predicates", CMDx::Result::INITIALIZED
    end
  end

  describe ".on_[STATES]" do
    context "with block" do
      it "executes block depending on state" do
        states = []

        result
          .on_initialized { |r| states << [1, r.state] }
          .on_executing { |r| states << [2, r.state] }
          .on_complete { |r| states << [3, r.state] }
          .on_interrupted { |r| states << [4, r.state] }
          .on_good { states << [5, "good"] }
          .on_bad { states << [6, "bad"] }

        expect(result.success?).to be(true)
        expect(states).to eq([[3, CMDx::Result::COMPLETE], [5, "good"]])
      end
    end

    context "without block" do
      it "executes block depending on status" do
        expect { result.on_success }.to raise_error(ArgumentError, "block required")
      end
    end
  end

  describe ".executed?" do
    it "returns value depending on state" do
      expect(initialized_result.executed?).to be(false)

      initialized_result.instance_variable_set(:@state, CMDx::Result::COMPLETE)

      expect(initialized_result.executed?).to be(true)
    end
  end

  describe ".executing!" do
    context "when transitioning from valid state" do
      it "updates state to executing" do
        initialized_result.executing!

        expect(initialized_result.state).to eq(CMDx::Result::EXECUTING)
      end
    end

    context "when transitioning from invalid state" do
      it "raises a RuntimeError" do
        initialized_result.instance_variable_set(:@state, CMDx::Result::COMPLETE)

        expect { initialized_result.executing! }.to raise_error(RuntimeError, "can only transition to executing from initialized")
      end
    end
  end

  describe ".complete!" do
    context "when transitioning from valid state" do
      it "updates state to complete" do
        initialized_result.instance_variable_set(:@state, CMDx::Result::EXECUTING)

        initialized_result.complete!

        expect(initialized_result.state).to eq(CMDx::Result::COMPLETE)
      end
    end

    context "when transitioning from invalid state" do
      it "raises a RuntimeError" do
        initialized_result.instance_variable_set(:@state, CMDx::Result::INTERRUPTED)

        expect { initialized_result.complete! }.to raise_error(RuntimeError, "can only transition to complete from executing")
      end
    end
  end

  describe ".interrupt!" do
    context "when transitioning from valid state" do
      it "updates state to interrupted" do
        initialized_result.instance_variable_set(:@state, CMDx::Result::EXECUTING)

        initialized_result.interrupt!

        expect(initialized_result.state).to eq(CMDx::Result::INTERRUPTED)
      end
    end

    context "when transitioning from invalid state" do
      it "raises a RuntimeError" do
        initialized_result.instance_variable_set(:@state, CMDx::Result::COMPLETE)

        expect { initialized_result.interrupt! }.to raise_error(RuntimeError, "cannot transition to interrupted from complete")
      end
    end
  end

  describe "status predicate methods" do
    context "when initialized with success status" do
      subject(:result) { initialized_result }

      it_behaves_like "result status predicates", CMDx::Result::SUCCESS
    end
  end

  describe ".on_[STATUSES]" do
    context "with block" do
      it "executes block depending on status" do
        statuses = []

        result
          .on_success { |r| statuses << [1, r.status] }
          .on_skipped { |r| statuses << [2, r.status] }
          .on_failed { |r| statuses << [3, r.status] }
          .on_good { statuses << [4, "good"] }
          .on_bad { statuses << [5, "bad"] }

        expect(result.success?).to be(true)
        expect(statuses).to eq([[1, CMDx::Result::SUCCESS], [4, "good"]])
      end
    end

    context "without block" do
      it "executes block depending on status" do
        expect { result.on_success }.to raise_error(ArgumentError, "block required")
      end
    end
  end

  describe ".good?" do
    it "returns value depending on status" do
      expect(initialized_result.good?).to be(true)

      initialized_result.instance_variable_set(:@status, CMDx::Result::FAILED)

      expect(initialized_result.good?).to be(false)
    end
  end

  describe ".skip!" do
    context "when transitioning from valid status" do
      it "updates status to skipped and raises a Skipped fault" do
        expect { initialized_result.skip! }.to raise_error(CMDx::Skipped, "no reason given")
      end
    end

    context "when transitioning from invalid status" do
      it "raises a RuntimeError" do
        initialized_result.instance_variable_set(:@status, CMDx::Result::FAILED)

        expect { initialized_result.skip! }.to raise_error(RuntimeError, "can only transition to skipped from success")
      end
    end
  end

  describe ".fail!" do
    context "when transitioning from valid status" do
      it "updates status to failed and raises a Failed fault" do
        expect { initialized_result.fail! }.to raise_error(CMDx::Failed, "no reason given")
      end
    end

    context "when transitioning from invalid status" do
      it "raises a RuntimeError" do
        initialized_result.instance_variable_set(:@status, CMDx::Result::SKIPPED)

        expect { initialized_result.fail! }.to raise_error(RuntimeError, "can only transition to failed from success")
      end
    end
  end

  describe ".halt!" do
    context "when success" do
      it "does nothing" do
        expect { result.halt! }.not_to raise_error
      end
    end

    context "when skipped" do
      let(:simulate) { :skipped }

      it "raises a Skipped fault" do
        expect { result.halt! }.to raise_error(CMDx::Skipped)
      end
    end

    context "when failed" do
      let(:simulate) { :failed }

      it "raises a Failed fault" do
        expect { result.halt! }.to raise_error(CMDx::Failed)
      end
    end
  end

  describe ".throw!" do
    let(:anonymous_result) { described_class.new(result.task) }

    context "when success" do
      it "does nothing" do
        expect { anonymous_result.throw!(result) }.not_to raise_error
      end
    end

    context "when skipped" do
      let(:simulate) { :skipped }

      it "raises a Skipped fault" do
        expect { anonymous_result.throw!(result) }.to raise_error(CMDx::Skipped)
      end
    end

    context "when failed" do
      let(:simulate) { :failed }

      it "raises a Failed fault" do
        expect { anonymous_result.throw!(result) }.to raise_error(CMDx::Failed)
      end
    end

    context "when not given a result" do
      it "raises an TypeError" do
        expect { anonymous_result.throw!(nil) }.to raise_error(TypeError, "must be a Result")
      end
    end
  end

  describe "#cause_and_throw" do
    context "when parent failed" do
      let(:simulate) { :failed }

      it "returns correct data" do
        expect(result).to be_failed
        expect(result.caused_failure.index).to eq(0)
        expect(result.caused_failure).to eq(result)
        expect(result).to be_caused_failure
        expect(result.threw_failure.index).to eq(0)
        expect(result.threw_failure).to eq(result)
        expect(result).to be_threw_failure
        expect(result).not_to be_thrown_failure
        expect(result.run.results.size).to eq(1)
      end
    end

    context "when child failed" do
      let(:simulate) { :child_failed }

      it "returns correct data" do
        expect(result).to be_failed
        expect(result.caused_failure.index).to eq(1)
        expect(result.caused_failure).not_to eq(result)
        expect(result).not_to be_caused_failure
        expect(result.threw_failure.index).to eq(1)
        expect(result.threw_failure).not_to eq(result)
        expect(result).not_to be_threw_failure
        expect(result).to be_thrown_failure
        expect(result.run.results.size).to eq(2)
      end
    end

    context "when grand child failed" do
      let(:simulate) { :grand_child_failed }

      it "returns correct data" do
        expect(result).to be_failed
        expect(result.caused_failure.index).to eq(2)
        expect(result.caused_failure).not_to eq(result)
        expect(result).not_to be_caused_failure
        expect(result.threw_failure.index).to eq(1)
        expect(result.threw_failure).not_to eq(result)
        expect(result).not_to be_threw_failure
        expect(result).to be_thrown_failure
        expect(result.run.results.size).to eq(3)
      end
    end
  end

  describe ".index" do
    it "returns 0" do
      expect(result.index).to be_zero
    end
  end

  describe ".runtime" do
    context "when runtime not captured" do
      it "returns nil" do
        expect(initialized_result.runtime).to be_nil
      end
    end

    context "when runtime captured" do
      it "returns value" do
        expect(result.runtime).not_to be_nil
      end
    end
  end

  describe ".to_s" do
    it "returns a string representation" do
      expect(result.to_s).to be_a(String)
    end
  end

  describe "pattern matching" do
    describe "#deconstruct" do
      it "returns array with state and status" do
        expect(result.deconstruct).to eq(%w[complete success])
      end

      it "supports array pattern matching" do
        matched = case result
                  in ["complete", "success"]
                    true
                  else
                    false
                  end

        expect(matched).to be(true)
      end

      it "matches failed results" do
        failed_result = SimulationTask.call(simulate: :fail)

        matched = case failed_result
                  in ["interrupted", "failed"]
                    true
                  else
                    false
                  end

        expect(matched).to be(true)
      end
    end

    describe "#deconstruct_keys" do
      it "returns hash with all attributes when keys is nil" do
        keys_hash = result.deconstruct_keys(nil)

        expect(keys_hash).to include(
          state: "complete",
          status: "success",
          metadata: {},
          executed: true,
          good: true,
          bad: false
        )
      end

      it "returns specific keys when requested" do
        keys_hash = result.deconstruct_keys(%i[state status])

        expect(keys_hash).to eq({
                                  state: "complete",
                                  status: "success"
                                })
      end

      it "supports hash pattern matching" do
        matched = case result
                  in { state: "complete", status: "success" }
                    true
                  else
                    false
                  end

        expect(matched).to be(true)
      end

      it "matches against boolean attributes" do
        matched = case result
                  in { good: true, bad: false }
                    true
                  else
                    false
                  end

        expect(matched).to be(true)
      end

      it "matches failed results with metadata" do
        failed_result = SimulationTask.call(simulate: :fail)

        matched = case failed_result
                  in { state: "interrupted", status: "failed", metadata: Hash }
                    true
                  else
                    false
                  end

        expect(matched).to be(true)
      end
    end
  end
end

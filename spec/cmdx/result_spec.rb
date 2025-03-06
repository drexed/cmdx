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

  describe ".[STATES]?" do
    it "returns value depending on state" do
      expect(initialized_result.initialized?).to be(true)
      expect(initialized_result.executing?).to be(false)
      expect(initialized_result.complete?).to be(false)
      expect(initialized_result.interrupted?).to be(false)
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

  describe ".[STATUSES]?" do
    it "returns value depending on status" do
      expect(initialized_result.success?).to be(true)
      expect(initialized_result.skipped?).to be(false)
      expect(initialized_result.failed?).to be(false)
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
      it "raises an ArgumentError" do
        expect { anonymous_result.throw!(nil) }.to raise_error(ArgumentError, "must be a Result")
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
    context "when within timeout threshold" do
      subject(:result) { simulation_task.call(simulate:) }

      let(:simulation_task) do
        Class.new(SimulationTask) do
          task_settings!(task_timeout: 1)

          def call
            sleep(0.1)
          end
        end
      end

      it "returns success" do
        expect(result).to be_success
      end
    end

    context "when beyond timeout threshold" do
      subject(:result) { simulation_task.call(simulate:) }

      let(:simulation_task) do
        Class.new(SimulationTask) do
          task_settings!(task_timeout: 0.1)

          def call
            sleep(1)
          end
        end
      end

      it "raises Timeout error" do
        expect { result }.to raise_error(CMDx::TimeoutError, "execution exceeded 0.1 seconds")
      end
    end

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

end

# frozen_string_literal: true

RSpec.describe CMDx::Outcome do
  subject(:outcome) { described_class.new }

  describe "initial state" do
    it "starts initialized and successful" do
      expect(outcome).to be_initialized
      expect(outcome).to be_success
      expect(outcome).not_to be_executed
    end
  end

  describe "state transitions" do
    it "transitions initialized -> executing -> complete" do
      outcome.executing!
      expect(outcome).to be_executing
      outcome.complete!
      expect(outcome).to be_complete
      expect(outcome).to be_executed
    end

    it "transitions initialized -> executing -> interrupted" do
      outcome.executing!
      outcome.interrupt!
      expect(outcome).to be_interrupted
    end

    it "rejects invalid transitions" do
      expect { outcome.complete! }.to raise_error(RuntimeError, /cannot transition/)
    end

    it "rejects complete -> interrupted" do
      outcome.executing!
      outcome.complete!
      expect { outcome.interrupt! }.to raise_error(RuntimeError, /cannot transition/)
    end
  end

  describe "#fail!" do
    it "sets failed status and reason" do
      outcome.fail!("broke", cause: StandardError.new("boom"))
      expect(outcome).to be_failed
      expect(outcome).to be_interrupted
      expect(outcome.reason).to eq("broke")
      expect(outcome.cause).to be_a(StandardError)
    end
  end

  describe "#apply_signal" do
    it "applies a skip signal" do
      outcome.apply_signal(status: :skipped, reason: "not needed", strict: false)
      expect(outcome).to be_skipped
      expect(outcome.reason).to eq("not needed")
      expect(outcome.metadata[:strict]).to be false
    end
  end

  describe "#finalize_state!" do
    it "completes when successful" do
      outcome.executing!
      outcome.finalize_state!
      expect(outcome).to be_complete
    end

    it "interrupts when failed" do
      outcome.executing!
      outcome.fail!("err")
      outcome.finalize_state!
      expect(outcome).to be_interrupted
    end
  end
end

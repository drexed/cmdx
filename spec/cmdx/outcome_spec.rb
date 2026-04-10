# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Outcome do
  describe "defaults" do
    it "initializes lifecycle and outcome fields" do
      o = described_class.new
      expect(o.state).to eq("initialized")
      expect(o.status).to eq("success")
      expect(o.metadata).to eq({})
      expect(o.strict).to be true
      expect(o.retries).to eq(0)
      expect(o.rolled_back).to be false
    end
  end

  describe "#success?, #failed?, #skipped?" do
    it "matches string status values" do
      expect(described_class.new(status: "success").success?).to be true
      expect(described_class.new(status: "failed").failed?).to be true
      expect(described_class.new(status: "skipped").skipped?).to be true
    end
  end

  describe "#apply_signal" do
    let(:outcome) { described_class.new }

    it "no-ops on nil" do
      expect { outcome.apply_signal(nil) }.not_to change(outcome, :status)
    end

    it "sets status, reason, strict, and merges metadata for non-success outcomes" do
      outcome.apply_signal(
        status: :failed,
        reason: "blocked",
        strict: false,
        metadata: { step: 1 }
      )
      expect(outcome.status).to eq("failed")
      expect(outcome.reason).to eq("blocked")
      expect(outcome.strict).to be false
      expect(outcome.metadata).to eq({ step: 1 })
    end

    it "fills an unspecified reason from locale when status is not success" do
      outcome.apply_signal(status: "skipped")
      expect(outcome.reason).to eq("Unspecified")
    end

    it "assigns cause when present in the signal" do
      err = StandardError.new("boom")
      outcome.apply_signal(status: "failed", cause: err)
      expect(outcome.cause).to equal(err)
    end
  end
end

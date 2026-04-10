# frozen_string_literal: true

RSpec.describe CMDx::RetryPolicy do
  describe "#matches?" do
    it "matches configured exception classes" do
      policy = described_class.new(3, retry_on: [ArgumentError])
      expect(policy.matches?(ArgumentError.new)).to be true
      expect(policy.matches?(RuntimeError.new)).to be false
    end

    it "matches StandardError by default" do
      policy = described_class.new(1)
      expect(policy.matches?(StandardError.new)).to be true
    end
  end

  describe "#max_retries" do
    it "returns configured count" do
      expect(described_class.new(5).max_retries).to eq(5)
    end
  end
end

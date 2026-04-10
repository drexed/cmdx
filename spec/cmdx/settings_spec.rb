# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Settings do
  describe "lazy accessors" do
    it "returns nil for unset values" do
      s = described_class.new
      expect(s.logger).to be_nil
      expect(s.log_level).to be_nil
      expect(s.tags).to be_nil
      expect(s.on_failure).to be_nil
      expect(s.retry_count).to be_nil
      expect(s.deprecate).to be_nil
    end
  end

  describe "parent delegation" do
    it "resolves through parent for resolved_* readers" do
      parent = described_class.new
      parent.tags = %i[a b]
      parent.on_failure = :skip
      parent.retry_count = 2
      parent.retry_delay = 0.5
      parent.retry_jitter = 0.1
      parent.retry_on = [ArgumentError]

      child = described_class.new(parent)

      expect(child.resolved_tags).to eq(%i[a b])
      expect(child.resolved_on_failure).to eq(:skip)
      expect(child.resolved_retry_count).to eq(2)
      expect(child.resolved_retry_delay).to eq(0.5)
      expect(child.resolved_retry_jitter).to eq(0.1)
      expect(child.resolved_retry_on).to eq([ArgumentError])
    end
  end

  describe "global configuration fallback" do
    it "falls back to CMDx.configuration.logger for resolved_logger" do
      global = CMDx.configuration.logger
      child = described_class.new
      expect(child.resolved_logger).to be(global)
    end
  end

  describe "#for_child" do
    it "returns a new Settings with self as parent" do
      parent = described_class.new
      parent.tags = [:x]

      child = parent.for_child
      expect(child.parent).to be(parent)
      expect(child.resolved_tags).to eq([:x])
    end
  end

  describe "#retryable?" do
    it "is false when retry count resolves to zero" do
      expect(described_class.new.retryable?).to be(false)
    end

    it "is true when retry count resolves positive" do
      s = described_class.new
      s.retry_count = 1
      expect(s.retryable?).to be(true)
    end
  end

  describe "#deprecated?" do
    it "is false when deprecate resolves to nil" do
      expect(described_class.new.deprecated?).to be(false)
    end

    it "is true when deprecate is set on self or parent" do
      parent = described_class.new
      parent.deprecate = { message: "nope" }
      expect(parent.deprecated?).to be(true)
      expect(described_class.new(parent).deprecated?).to be(true)
    end
  end
end

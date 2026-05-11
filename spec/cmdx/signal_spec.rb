# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Signal do
  describe ".success" do
    context "with a reason" do
      it "builds a new complete/success signal with the reason" do
        signal = described_class.success("ok now")

        expect(signal).to have_attributes(
          state: described_class::COMPLETE,
          status: described_class::SUCCESS,
          reason: "ok now"
        )
        expect(signal).not_to be(described_class.success)
      end
    end

    context "with options" do
      it "stores metadata, cause, and backtrace" do
        cause = StandardError.new("inner")
        signal = described_class.success(metadata: { code: 1 }, cause:, backtrace: %w[a b])

        expect(signal).to have_attributes(
          metadata: { code: 1 },
          cause:,
          backtrace: %w[a b]
        )
      end
    end
  end

  describe ".skipped" do
    it "builds an interrupted/skipped signal when given a reason" do
      signal = described_class.skipped("nope")

      expect(signal).to have_attributes(
        state: described_class::INTERRUPTED,
        status: described_class::SKIPPED,
        reason: "nope"
      )
    end
  end

  describe ".failed" do
    it "builds an interrupted/failed signal when given a reason" do
      signal = described_class.failed("broken")

      expect(signal).to have_attributes(
        state: described_class::INTERRUPTED,
        status: described_class::FAILED,
        reason: "broken"
      )
    end
  end

  describe ".echoed" do
    context "when given a Signal" do
      it "copies state, status, and reason and applies new options" do
        source = described_class.failed("boom", metadata: { x: 1 })
        echoed = described_class.echoed(source, metadata: { y: 2 })

        expect(echoed).to have_attributes(
          state: described_class::INTERRUPTED,
          status: described_class::FAILED,
          reason: "boom",
          metadata: { y: 2 }
        )
      end
    end

    context "when given a non-Signal/non-Result" do
      it "raises ArgumentError" do
        expect { described_class.echoed(Object.new) }
          .to raise_error(ArgumentError, /Signal\.echoed expected a Result or Signal/)
      end
    end
  end

  describe "singletons" do
    it "expose the canonical state/status pairs" do
      expect(described_class.success).to have_attributes(
        state: described_class::COMPLETE, status: described_class::SUCCESS
      )
      expect(described_class.skipped).to have_attributes(
        state: described_class::INTERRUPTED, status: described_class::SKIPPED
      )
      expect(described_class.failed).to have_attributes(
        state: described_class::INTERRUPTED, status: described_class::FAILED
      )
    end
  end

  describe "state predicates" do
    it "complete? is true only for COMPLETE state" do
      expect(described_class.success.complete?).to be(true)
      expect(described_class.failed.complete?).to be(false)
    end

    it "interrupted? is true only for INTERRUPTED state" do
      expect(described_class.success.interrupted?).to be(false)
      expect(described_class.failed.interrupted?).to be(true)
      expect(described_class.skipped.interrupted?).to be(true)
    end
  end

  describe "status predicates" do
    it "success? / skipped? / failed? match status" do
      expect(described_class.success.success?).to be(true)
      expect(described_class.skipped.skipped?).to be(true)
      expect(described_class.failed.failed?).to be(true)

      expect(described_class.success.failed?).to be(false)
      expect(described_class.failed.success?).to be(false)
    end

    it "ok? is true when not failed" do
      expect(described_class.success.ok?).to be(true)
      expect(described_class.skipped.ok?).to be(true)
      expect(described_class.failed.ok?).to be(false)
    end

    it "ko? is true when not success" do
      expect(described_class.success.ko?).to be(false)
      expect(described_class.skipped.ko?).to be(true)
      expect(described_class.failed.ko?).to be(true)
    end
  end

  describe "#reason / #metadata / #cause / #backtrace" do
    subject(:signal) do
      described_class.new(
        described_class::INTERRUPTED,
        described_class::FAILED,
        reason: "r",
        metadata: { k: :v },
        cause:,
        backtrace: %w[line1 line2]
      )
    end

    let(:cause) { StandardError.new("inner") }

    it "exposes each option" do
      expect(signal).to have_attributes(
        reason: "r",
        metadata: { k: :v },
        cause:,
        backtrace: %w[line1 line2]
      )
    end

    it "defaults metadata to an empty hash when omitted" do
      signal = described_class.new(described_class::COMPLETE, described_class::SUCCESS)
      expect(signal.metadata).to eq({})
      expect(signal.metadata).to be_frozen
    end

    it "returns nil for unset reason/cause/backtrace" do
      signal = described_class.new(described_class::COMPLETE, described_class::SUCCESS)

      expect(signal.reason).to be_nil
      expect(signal.cause).to be_nil
      expect(signal.backtrace).to be_nil
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultLogger do
  let(:task) { create_simple_task(name: "TestTask").new }
  let(:result) { CMDx::Result.new(task) }
  let(:logger) { double("logger") }

  before do
    allow(task).to receive(:logger).and_return(logger)
  end

  describe "STATUS_TO_SEVERITY" do
    it "maps SUCCESS to info" do
      expect(described_class::STATUS_TO_SEVERITY[CMDx::Result::SUCCESS]).to eq(:info)
    end

    it "maps SKIPPED to warn" do
      expect(described_class::STATUS_TO_SEVERITY[CMDx::Result::SKIPPED]).to eq(:warn)
    end

    it "maps FAILED to error" do
      expect(described_class::STATUS_TO_SEVERITY[CMDx::Result::FAILED]).to eq(:error)
    end

    it "is frozen" do
      expect(described_class::STATUS_TO_SEVERITY).to be_frozen
    end
  end

  describe ".call" do
    context "when logger is nil" do
      before do
        allow(task).to receive(:logger).and_return(nil)
      end

      it "returns early without logging" do
        expect(logger).not_to receive(:with_level)
        expect(logger).not_to receive(:info)

        described_class.call(result)
      end
    end

    context "when result has SUCCESS status" do
      it "logs at info level" do
        expect(logger).to receive(:with_level).with(:info).and_yield
        expect(logger).to receive(:info).and_yield.and_return(result)

        described_class.call(result)
      end
    end

    context "when result has SKIPPED status" do
      before do
        result.skip!(original_exception: StandardError.new)
      end

      it "logs at warn level" do
        expect(logger).to receive(:with_level).with(:warn).and_yield
        expect(logger).to receive(:warn).and_yield.and_return(result)

        described_class.call(result)
      end
    end

    context "when result has FAILED status" do
      before do
        result.fail!(original_exception: StandardError.new)
      end

      it "logs at error level" do
        expect(logger).to receive(:with_level).with(:error).and_yield
        expect(logger).to receive(:error).and_yield.and_return(result)

        described_class.call(result)
      end
    end

    context "with logger interaction" do
      it "passes result to logger block" do
        logged_result = nil

        allow(logger).to receive(:with_level).with(:info).and_yield
        allow(logger).to receive(:info) do |&block|
          logged_result = block.call
        end

        described_class.call(result)

        expect(logged_result).to eq(result)
      end

      it "uses private logger method from task" do
        expect(task).to receive(:logger).and_return(logger)
        allow(logger).to receive(:with_level).and_yield
        allow(logger).to receive(:info)

        described_class.call(result)
      end
    end
  end
end

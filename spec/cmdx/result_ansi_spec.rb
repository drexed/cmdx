# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultAnsi do
  describe ".call" do
    let(:formatted_string) { "\e[32mtest\e[0m" }

    before do
      allow(CMDx::Utils::AnsiColor).to receive(:call).and_return(formatted_string)
    end

    context "with result states" do
      it "formats initialized state with blue color" do
        described_class.call(CMDx::Result::INITIALIZED)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("initialized", color: :blue)
      end

      it "formats executing state with yellow color" do
        described_class.call(CMDx::Result::EXECUTING)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("executing", color: :yellow)
      end

      it "formats complete state with green color" do
        described_class.call(CMDx::Result::COMPLETE)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("complete", color: :green)
      end

      it "formats interrupted state with red color" do
        described_class.call(CMDx::Result::INTERRUPTED)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("interrupted", color: :red)
      end
    end

    context "with result statuses" do
      it "formats success status with green color" do
        described_class.call(CMDx::Result::SUCCESS)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("success", color: :green)
      end

      it "formats skipped status with yellow color" do
        described_class.call(CMDx::Result::SKIPPED)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("skipped", color: :yellow)
      end

      it "formats failed status with red color" do
        described_class.call(CMDx::Result::FAILED)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("failed", color: :red)
      end
    end

    context "with unknown values" do
      it "formats unknown string with default color" do
        described_class.call("unknown")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("unknown", color: :default)
      end

      it "formats empty string with default color" do
        described_class.call("")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("", color: :default)
      end

      it "formats nil with default color" do
        described_class.call(nil)

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(nil, color: :default)
      end
    end

    it "returns the formatted string from Utils::AnsiColor" do
      result = described_class.call(CMDx::Result::SUCCESS)

      expect(result).to eq(formatted_string)
    end
  end

  describe ".color" do
    context "with result states" do
      it "returns blue for initialized state" do
        expect(described_class.color(CMDx::Result::INITIALIZED)).to eq(:blue)
      end

      it "returns yellow for executing state" do
        expect(described_class.color(CMDx::Result::EXECUTING)).to eq(:yellow)
      end

      it "returns green for complete state" do
        expect(described_class.color(CMDx::Result::COMPLETE)).to eq(:green)
      end

      it "returns red for interrupted state" do
        expect(described_class.color(CMDx::Result::INTERRUPTED)).to eq(:red)
      end
    end

    context "with result statuses" do
      it "returns green for success status" do
        expect(described_class.color(CMDx::Result::SUCCESS)).to eq(:green)
      end

      it "returns yellow for skipped status" do
        expect(described_class.color(CMDx::Result::SKIPPED)).to eq(:yellow)
      end

      it "returns red for failed status" do
        expect(described_class.color(CMDx::Result::FAILED)).to eq(:red)
      end
    end

    context "with unknown values" do
      it "returns default for unknown string" do
        expect(described_class.color("unknown")).to eq(:default)
      end

      it "returns default for empty string" do
        expect(described_class.color("")).to eq(:default)
      end

      it "returns default for nil" do
        expect(described_class.color(nil)).to eq(:default)
      end

      it "returns default for integer" do
        expect(described_class.color(123)).to eq(:default)
      end
    end
  end

  describe "constants" do
    describe "STATE_COLORS" do
      it "maps all result states to appropriate colors" do
        expect(described_class::STATE_COLORS).to eq(
          {
            CMDx::Result::INITIALIZED => :blue,
            CMDx::Result::EXECUTING => :yellow,
            CMDx::Result::COMPLETE => :green,
            CMDx::Result::INTERRUPTED => :red
          }
        )
      end

      it "is frozen" do
        expect(described_class::STATE_COLORS).to be_frozen
      end
    end

    describe "STATUS_COLORS" do
      it "maps all result statuses to appropriate colors" do
        expect(described_class::STATUS_COLORS).to eq(
          {
            CMDx::Result::SUCCESS => :green,
            CMDx::Result::SKIPPED => :yellow,
            CMDx::Result::FAILED => :red
          }
        )
      end

      it "is frozen" do
        expect(described_class::STATUS_COLORS).to be_frozen
      end
    end
  end

  describe "integration with real values" do
    let(:task) { create_simple_task(name: "TestTask").new }
    let(:result) { CMDx::Result.new(task) }

    before do
      allow(CMDx::Utils::AnsiColor).to receive(:call).and_return("formatted")
    end

    it "formats result state correctly" do
      described_class.call(result.state)

      expect(CMDx::Utils::AnsiColor).to have_received(:call).with("initialized", color: :blue)
    end

    it "formats result status correctly" do
      described_class.call(result.status)

      expect(CMDx::Utils::AnsiColor).to have_received(:call).with("success", color: :green)
    end

    it "handles state transitions" do
      result.executing!
      described_class.call(result.state)

      expect(CMDx::Utils::AnsiColor).to have_received(:call).with("executing", color: :yellow)

      result.complete!
      described_class.call(result.state)

      expect(CMDx::Utils::AnsiColor).to have_received(:call).with("complete", color: :green)
    end

    it "handles status transitions" do
      result.fail!(original_exception: StandardError.new)
      described_class.call(result.status)

      expect(CMDx::Utils::AnsiColor).to have_received(:call).with("failed", color: :red)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LoggerAnsi do
  describe ".call" do
    let(:message) { "DEBUG: Starting process" }
    let(:formatted_message) { "\e[1;34;49m#{message}\e[0m" }

    before do
      allow(CMDx::Utils::AnsiColor).to receive(:call).and_return(formatted_message)
    end

    it "delegates to Utils::AnsiColor with correct arguments" do
      described_class.call(message)

      expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
        message,
        color: :blue,
        mode: :bold
      )
    end

    it "returns the formatted message from Utils::AnsiColor" do
      result = described_class.call(message)

      expect(result).to eq(formatted_message)
    end

    context "with different severity levels" do
      it "formats debug messages with blue color" do
        described_class.call("DEBUG: test")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "DEBUG: test",
          color: :blue,
          mode: :bold
        )
      end

      it "formats info messages with green color" do
        described_class.call("INFO: test")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "INFO: test",
          color: :green,
          mode: :bold
        )
      end

      it "formats warning messages with yellow color" do
        described_class.call("WARN: test")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "WARN: test",
          color: :yellow,
          mode: :bold
        )
      end

      it "formats error messages with red color" do
        described_class.call("ERROR: test")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "ERROR: test",
          color: :red,
          mode: :bold
        )
      end

      it "formats fatal messages with magenta color" do
        described_class.call("FATAL: test")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "FATAL: test",
          color: :magenta,
          mode: :bold
        )
      end
    end

    context "with edge cases" do
      it "handles unknown severity with default color" do
        described_class.call("UNKNOWN: test")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "UNKNOWN: test",
          color: :default,
          mode: :bold
        )
      end

      it "handles empty string" do
        described_class.call("")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "",
          color: :default,
          mode: :bold
        )
      end

      it "handles single character messages" do
        described_class.call("D")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with(
          "D",
          color: :blue,
          mode: :bold
        )
      end
    end
  end

  describe ".color" do
    it "returns blue for debug messages" do
      expect(described_class.color("DEBUG: test")).to eq(:blue)
    end

    it "returns green for info messages" do
      expect(described_class.color("INFO: test")).to eq(:green)
    end

    it "returns yellow for warning messages" do
      expect(described_class.color("WARN: test")).to eq(:yellow)
    end

    it "returns red for error messages" do
      expect(described_class.color("ERROR: test")).to eq(:red)
    end

    it "returns magenta for fatal messages" do
      expect(described_class.color("FATAL: test")).to eq(:magenta)
    end

    it "returns default for unknown severity" do
      expect(described_class.color("UNKNOWN: test")).to eq(:default)
    end

    it "returns default for empty string" do
      expect(described_class.color("")).to eq(:default)
    end

    it "works with lowercase severity indicators" do
      expect(described_class.color("debug: test")).to eq(:default)
    end

    it "works with mixed case messages" do
      expect(described_class.color("Debug: test")).to eq(:blue)
    end

    it "handles numeric characters" do
      expect(described_class.color("1: test")).to eq(:default)
    end

    it "handles special characters" do
      expect(described_class.color("@: test")).to eq(:default)
    end
  end

  describe "SEVERITY_COLORS constant" do
    it "is frozen" do
      expect(described_class::SEVERITY_COLORS).to be_frozen
    end

    it "contains expected severity mappings" do
      expect(described_class::SEVERITY_COLORS).to eq(
        {
          "D" => :blue,
          "I" => :green,
          "W" => :yellow,
          "E" => :red,
          "F" => :magenta
        }
      )
    end
  end
end

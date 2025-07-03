# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LoggerAnsi do
  describe ".call" do
    context "when input is DEBUG severity" do
      it "returns blue bold formatted string" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("DEBUG", color: :blue, mode: :bold).and_return("\e[1;34mDEBUG\e[0m")

        result = described_class.call("DEBUG")

        expect(result).to eq("\e[1;34mDEBUG\e[0m")
      end

      it "calls AnsiColor with correct parameters" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("DEBUG")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("DEBUG", color: :blue, mode: :bold)
      end
    end

    context "when input is INFO severity" do
      it "returns green bold formatted string" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("INFO", color: :green, mode: :bold).and_return("\e[1;32mINFO\e[0m")

        result = described_class.call("INFO")

        expect(result).to eq("\e[1;32mINFO\e[0m")
      end

      it "calls AnsiColor with correct parameters" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("INFO")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("INFO", color: :green, mode: :bold)
      end
    end

    context "when input is WARN severity" do
      it "returns yellow bold formatted string" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("WARN", color: :yellow, mode: :bold).and_return("\e[1;33mWARN\e[0m")

        result = described_class.call("WARN")

        expect(result).to eq("\e[1;33mWARN\e[0m")
      end

      it "calls AnsiColor with correct parameters" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("WARN")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("WARN", color: :yellow, mode: :bold)
      end
    end

    context "when input is ERROR severity" do
      it "returns red bold formatted string" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("ERROR", color: :red, mode: :bold).and_return("\e[1;31mERROR\e[0m")

        result = described_class.call("ERROR")

        expect(result).to eq("\e[1;31mERROR\e[0m")
      end

      it "calls AnsiColor with correct parameters" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("ERROR")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("ERROR", color: :red, mode: :bold)
      end
    end

    context "when input is FATAL severity" do
      it "returns magenta bold formatted string" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("FATAL", color: :magenta, mode: :bold).and_return("\e[1;35mFATAL\e[0m")

        result = described_class.call("FATAL")

        expect(result).to eq("\e[1;35mFATAL\e[0m")
      end

      it "calls AnsiColor with correct parameters" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("FATAL")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("FATAL", color: :magenta, mode: :bold)
      end
    end

    context "when input is unknown severity" do
      it "returns default color bold formatted string" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("CUSTOM", color: :default, mode: :bold).and_return("\e[1;39mCUSTOM\e[0m")

        result = described_class.call("CUSTOM")

        expect(result).to eq("\e[1;39mCUSTOM\e[0m")
      end

      it "calls AnsiColor with default color" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("UNKNOWN")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("UNKNOWN", color: :default, mode: :bold)
      end
    end

    context "when input is lowercase severity" do
      it "treats as unknown and uses default color" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("debug", color: :default, mode: :bold).and_return("\e[1;39mdebug\e[0m")

        result = described_class.call("debug")

        expect(result).to eq("\e[1;39mdebug\e[0m")
      end
    end

    context "when input is empty string" do
      it "handles gracefully with default color" do
        allow(CMDx::Utils::AnsiColor).to receive(:call).with("", color: :default, mode: :bold).and_return("\e[1;39m\e[0m")

        result = described_class.call("")

        expect(result).to eq("\e[1;39m\e[0m")
      end
    end

    context "when input is single character" do
      it "maps D to blue" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("D")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("D", color: :blue, mode: :bold)
      end

      it "maps I to green" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("I")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("I", color: :green, mode: :bold)
      end

      it "maps W to yellow" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("W")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("W", color: :yellow, mode: :bold)
      end

      it "maps E to red" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("E")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("E", color: :red, mode: :bold)
      end

      it "maps F to magenta" do
        allow(CMDx::Utils::AnsiColor).to receive(:call)

        described_class.call("F")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("F", color: :magenta, mode: :bold)
      end
    end

    context "when AnsiColor raises an error" do
      before do
        allow(CMDx::Utils::AnsiColor).to receive(:call).and_raise(StandardError, "color error")
      end

      it "allows the error to propagate" do
        expect { described_class.call("INFO") }.to raise_error(StandardError, "color error")
      end
    end
  end

  describe ".color" do
    context "when input starts with D" do
      it "returns blue for DEBUG" do
        result = described_class.color("DEBUG")

        expect(result).to eq(:blue)
      end

      it "returns blue for single D" do
        result = described_class.color("D")

        expect(result).to eq(:blue)
      end

      it "returns blue for D with other text" do
        result = described_class.color("Debug Message")

        expect(result).to eq(:blue)
      end
    end

    context "when input starts with I" do
      it "returns green for INFO" do
        result = described_class.color("INFO")

        expect(result).to eq(:green)
      end

      it "returns green for single I" do
        result = described_class.color("I")

        expect(result).to eq(:green)
      end
    end

    context "when input starts with W" do
      it "returns yellow for WARN" do
        result = described_class.color("WARN")

        expect(result).to eq(:yellow)
      end

      it "returns yellow for WARNING" do
        result = described_class.color("WARNING")

        expect(result).to eq(:yellow)
      end
    end

    context "when input starts with E" do
      it "returns red for ERROR" do
        result = described_class.color("ERROR")

        expect(result).to eq(:red)
      end

      it "returns red for EXCEPTION" do
        result = described_class.color("EXCEPTION")

        expect(result).to eq(:red)
      end
    end

    context "when input starts with F" do
      it "returns magenta for FATAL" do
        result = described_class.color("FATAL")

        expect(result).to eq(:magenta)
      end

      it "returns magenta for FAILURE" do
        result = described_class.color("FAILURE")

        expect(result).to eq(:magenta)
      end
    end

    context "when input starts with unmapped character" do
      it "returns default for CUSTOM" do
        result = described_class.color("CUSTOM")

        expect(result).to eq(:default)
      end

      it "returns default for TRACE" do
        result = described_class.color("TRACE")

        expect(result).to eq(:default)
      end

      it "returns default for lowercase" do
        result = described_class.color("debug")

        expect(result).to eq(:default)
      end

      it "returns default for numbers" do
        result = described_class.color("123")

        expect(result).to eq(:default)
      end
    end

    context "when input is empty string" do
      it "handles gracefully and returns default" do
        result = described_class.color("")

        expect(result).to eq(:default)
      end
    end

    context "when input is not a string" do
      it "works with symbols" do
        result = described_class.color(:DEBUG)

        expect(result).to eq(:blue)
      end
    end
  end
end

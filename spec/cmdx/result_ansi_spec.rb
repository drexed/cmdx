# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultAnsi do
  describe ".call" do
    context "when colorizing result states" do
      it "applies blue color to initialized state" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("initialized", color: :blue)

        described_class.call("initialized")
      end

      it "applies yellow color to executing state" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("executing", color: :yellow)

        described_class.call("executing")
      end

      it "applies green color to complete state" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("complete", color: :green)

        described_class.call("complete")
      end

      it "applies red color to interrupted state" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("interrupted", color: :red)

        described_class.call("interrupted")
      end
    end

    context "when colorizing result statuses" do
      it "applies green color to success status" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("success", color: :green)

        described_class.call("success")
      end

      it "applies yellow color to skipped status" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("skipped", color: :yellow)

        described_class.call("skipped")
      end

      it "applies red color to failed status" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("failed", color: :red)

        described_class.call("failed")
      end
    end

    context "when colorizing unknown values" do
      it "applies default color to unknown state" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("unknown", color: :default)

        described_class.call("unknown")
      end

      it "applies default color to arbitrary string" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("pending", color: :default)

        described_class.call("pending")
      end

      it "applies default color to empty string" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("", color: :default)

        described_class.call("")
      end
    end

    context "when integrating with Utils::AnsiColor" do
      it "returns the formatted string from Utils::AnsiColor" do
        formatted_string = "\e[32msuccess\e[0m"
        allow(CMDx::Utils::AnsiColor).to receive(:call).and_return(formatted_string)

        result = described_class.call("success")

        expect(result).to eq(formatted_string)
      end

      it "passes through the original string and determined color" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("complete", color: :green).and_return("formatted")

        described_class.call("complete")
      end
    end
  end

  describe ".color" do
    context "when determining colors for result states" do
      it "returns blue for initialized state" do
        color = described_class.color("initialized")

        expect(color).to eq(:blue)
      end

      it "returns yellow for executing state" do
        color = described_class.color("executing")

        expect(color).to eq(:yellow)
      end

      it "returns green for complete state" do
        color = described_class.color("complete")

        expect(color).to eq(:green)
      end

      it "returns red for interrupted state" do
        color = described_class.color("interrupted")

        expect(color).to eq(:red)
      end
    end

    context "when determining colors for result statuses" do
      it "returns green for success status" do
        color = described_class.color("success")

        expect(color).to eq(:green)
      end

      it "returns yellow for skipped status" do
        color = described_class.color("skipped")

        expect(color).to eq(:yellow)
      end

      it "returns red for failed status" do
        color = described_class.color("failed")

        expect(color).to eq(:red)
      end
    end

    context "when determining colors for unknown values" do
      it "returns default for unknown state" do
        color = described_class.color("unknown")

        expect(color).to eq(:default)
      end

      it "returns default for arbitrary string" do
        color = described_class.color("pending")

        expect(color).to eq(:default)
      end

      it "returns default for empty string" do
        color = described_class.color("")

        expect(color).to eq(:default)
      end

      it "returns default for nil value" do
        color = described_class.color(nil)

        expect(color).to eq(:default)
      end
    end

    context "when handling color mapping behavior" do
      it "correctly identifies state colors" do
        state_values = %w[initialized executing complete interrupted]
        expected_colors = %i[blue yellow green red]

        state_values.each_with_index do |state, index|
          color = described_class.color(state)
          expect(color).to eq(expected_colors[index])
        end
      end

      it "correctly identifies status colors" do
        status_values = %w[success skipped failed]
        expected_colors = %i[green yellow red]

        status_values.each_with_index do |status, index|
          color = described_class.color(status)
          expect(color).to eq(expected_colors[index])
        end
      end

      it "falls back to default for unrecognized values" do
        unrecognized_values = %w[nonexistent invalid custom_state]

        unrecognized_values.each do |value|
          color = described_class.color(value)
          expect(color).to eq(:default)
        end
      end
    end
  end

  describe "integration with result values" do
    context "when using actual result constants" do
      it "handles complete state with success status combination" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("complete", color: :green)
        described_class.call("complete")

        expect(CMDx::Utils::AnsiColor).to receive(:call).with("success", color: :green)
        described_class.call("success")
      end

      it "handles interrupted state with failed status combination" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("interrupted", color: :red)
        described_class.call("interrupted")

        expect(CMDx::Utils::AnsiColor).to receive(:call).with("failed", color: :red)
        described_class.call("failed")
      end

      it "handles executing state with mixed status scenarios" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("executing", color: :yellow)
        described_class.call("executing")

        expect(CMDx::Utils::AnsiColor).to receive(:call).with("skipped", color: :yellow)
        described_class.call("skipped")
      end
    end

    context "when working with result inspection scenarios" do
      it "provides consistent colors for result display" do
        states = %w[initialized executing complete interrupted]
        statuses = %w[success skipped failed]

        states.each do |state|
          expect(CMDx::Utils::AnsiColor).to receive(:call).with(state, color: anything)
          described_class.call(state)
        end

        statuses.each do |status|
          expect(CMDx::Utils::AnsiColor).to receive(:call).with(status, color: anything)
          described_class.call(status)
        end
      end

      it "handles case sensitivity correctly" do
        expect(CMDx::Utils::AnsiColor).to receive(:call).with("COMPLETE", color: :default)
        described_class.call("COMPLETE")

        expect(CMDx::Utils::AnsiColor).to receive(:call).with("Success", color: :default)
        described_class.call("Success")
      end
    end

    context "when testing color consistency between call and color methods" do
      it "ensures call and color methods return consistent results" do
        test_values = %w[initialized executing complete interrupted success skipped failed unknown]

        test_values.each do |value|
          expected_color = described_class.color(value)
          expect(CMDx::Utils::AnsiColor).to receive(:call).with(value, color: expected_color)
          described_class.call(value)
        end
      end

      it "handles edge cases consistently" do
        edge_cases = ["", nil, "mixed_CASE", "123", "special-chars"]

        edge_cases.each do |value|
          expected_color = described_class.color(value)
          expect(expected_color).to eq(:default)
          expect(CMDx::Utils::AnsiColor).to receive(:call).with(value, color: :default)
          described_class.call(value)
        end
      end
    end
  end
end

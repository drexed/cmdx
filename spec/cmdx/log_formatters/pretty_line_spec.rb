# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyLine do
  describe "#call" do
    let(:task) { mock_task(class: double(name: "TestTask")) }
    let(:time) { Time.utc(2022, 7, 17, 18, 43, 15) }
    let(:serialized_data) do
      {
        index: 0,
        chain_id: "test-chain-id",
        type: "Task",
        class: "TestTask",
        state: "complete",
        status: "success",
        outcome: "success",
        runtime: 15,
        origin: "CMDx"
      }
    end

    before do
      allow(CMDx::LoggerSerializer).to receive(:call).and_return(serialized_data)
      allow(CMDx::Utils::LogTimestamp).to receive(:call).and_return("2022-07-17T18:43:15")
      allow(Process).to receive(:pid).and_return(1234)
      allow(CMDx::Utils::AnsiColor).to receive(:call).and_return("colored_text")
      allow(CMDx::ResultAnsi).to receive(:call).and_return("colored_result")
    end

    context "with basic log entry" do
      it "returns ANSI-colored line formatted string with newline" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("colored_text")
        expect(result).to include("TestTask")
      end

      it "includes colored severity initial in line format" do
        described_class.new.call("INFO", time, task, "Test message")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("I", color: :green, mode: :bold)
      end

      it "includes colored timestamp in brackets" do
        described_class.new.call("INFO", time, task, "Test message")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(time.utc)
      end

      it "includes process ID in brackets" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("#1234")
      end

      it "includes task class name" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("TestTask")
      end
    end

    context "with different severity levels" do
      it "formats DEBUG severity with blue color" do
        described_class.new.call("DEBUG", time, task, "Debug message")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("D", color: :blue, mode: :bold)
        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("DEBUG", color: :blue, mode: :bold)
      end

      it "formats INFO severity with green color" do
        described_class.new.call("INFO", time, task, "Info message")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("I", color: :green, mode: :bold)
        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("INFO", color: :green, mode: :bold)
      end

      it "formats WARN severity with yellow color" do
        described_class.new.call("WARN", time, task, "Warning message")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("W", color: :yellow, mode: :bold)
        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("WARN", color: :yellow, mode: :bold)
      end

      it "formats ERROR severity with red color" do
        described_class.new.call("ERROR", time, task, "Error message")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("E", color: :red, mode: :bold)
        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("ERROR", color: :red, mode: :bold)
      end

      it "formats FATAL severity with magenta color" do
        described_class.new.call("FATAL", time, task, "Fatal message")

        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("F", color: :magenta, mode: :bold)
        expect(CMDx::Utils::AnsiColor).to have_received(:call).with("FATAL", color: :magenta, mode: :bold)
      end
    end

    context "with ANSI color integration" do
      it "applies colors to severity and metadata" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("colored_text")
        expect(result).to end_with("\n")
      end

      it "follows traditional Ruby logger format structure with colors" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include(", [")
        expect(result).to include("] ")
        expect(result).to include(" -- ")
        expect(result).to include(": ")
      end

      it "produces single-line colored output" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result.count("\n")).to eq(1)
        expect(result.chomp).not_to include("\n")
      end
    end

    context "with different message types" do
      it "handles string messages" do
        result = described_class.new.call("INFO", time, task, "String message")

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("-- ")
      end

      it "handles hash messages" do
        hash_message = { key: "value", number: 42 }
        result = described_class.new.call("INFO", time, task, hash_message)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("-- ")
      end

      it "handles array messages" do
        array_message = %w[item1 item2 item3]
        result = described_class.new.call("INFO", time, task, array_message)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("-- ")
      end
    end

    context "with time conversion" do
      it "converts time to UTC before formatting" do
        local_time = Time.new(2022, 7, 17, 20, 43, 15)
        expected_utc = local_time.utc

        described_class.new.call("INFO", local_time, task, "Test message")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(expected_utc)
      end

      it "handles already UTC time correctly" do
        utc_time = Time.utc(2022, 7, 17, 18, 43, 15)

        described_class.new.call("INFO", utc_time, task, "Test message")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(utc_time)
      end
    end

    context "with LoggerSerializer integration" do
      it "calls LoggerSerializer with correct parameters" do
        message = "Test message"

        described_class.new.call("INFO", time, task, message)

        expect(CMDx::LoggerSerializer).to have_received(:call).with("INFO", time, task, message, ansi_colorize: true)
      end

      it "uses LoggerSerializer return value in message section" do
        custom_data = { custom_field: "custom_value" }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(custom_data)

        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("custom_field=custom_value")
      end
    end
  end
end

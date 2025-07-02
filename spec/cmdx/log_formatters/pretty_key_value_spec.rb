# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyKeyValue do
  describe "#call" do
    let(:task) { mock_task(class: double(name: "TestTask")) }
    let(:time) { Time.new(2022, 7, 17, 20, 43, 15) }
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
      allow(CMDx::Utils::LogTimestamp).to receive(:call).and_return("2022-07-17T18:43:15.123456")
      allow(Process).to receive(:pid).and_return(1234)
    end

    context "with basic log entry" do
      it "returns key=value formatted string with newline" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("=")
        expect(result).to include("severity=INFO")
        expect(result).to include("pid=1234")
        expect(result).to include("timestamp=2022-07-17T18:43:15.123456")
      end

      it "calls LoggerSerializer with ansi_colorize enabled" do
        described_class.new.call("INFO", time, task, "Test message")

        expect(CMDx::LoggerSerializer).to have_received(:call).with("INFO", time, task, "Test message", ansi_colorize: true)
      end

      it "includes process ID in output" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("pid=1234")
      end

      it "includes timestamp in output" do
        described_class.new.call("INFO", time, task, "Test message")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(time.utc)
      end
    end

    context "with different severity levels" do
      it "formats DEBUG severity" do
        result = described_class.new.call("DEBUG", time, task, "Debug message")

        expect(result).to include("severity=DEBUG")
      end

      it "formats WARN severity" do
        result = described_class.new.call("WARN", time, task, "Warning message")

        expect(result).to include("severity=WARN")
      end

      it "formats ERROR severity" do
        result = described_class.new.call("ERROR", time, task, "Error message")

        expect(result).to include("severity=ERROR")
      end

      it "formats FATAL severity" do
        result = described_class.new.call("FATAL", time, task, "Fatal message")

        expect(result).to include("severity=FATAL")
      end
    end

    context "with ANSI color integration" do
      let(:result_message) do
        mock_result(to_h: {
                      state: "complete",
                      status: "success",
                      outcome: "success",
                      runtime: 15
                    },
                    is_a?: true)
      end

      before do
        allow(result_message).to receive(:is_a?).with(CMDx::Result).and_return(true)
        allow(CMDx::ResultAnsi).to receive(:call).and_return("colored_value")
      end

      it "applies colors to result state/status/outcome values through LoggerSerializer" do
        described_class.new.call("INFO", time, task, result_message)

        expect(CMDx::LoggerSerializer).to have_received(:call).with("INFO", time, task, result_message, ansi_colorize: true)
      end
    end

    context "with different message types" do
      it "handles string messages" do
        result = described_class.new.call("INFO", time, task, "String message")

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "handles hash messages" do
        hash_message = { action: "process", item_id: 123 }
        serialized_with_hash = serialized_data.merge(hash_message)
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(serialized_with_hash)

        result = described_class.new.call("INFO", time, task, hash_message)

        expect(result).to include("action=process")
        expect(result).to include("item_id=123")
      end

      it "handles nil messages" do
        result = described_class.new.call("INFO", time, task, nil)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
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

      it "merges LoggerSerializer result with severity, pid, and timestamp" do
        custom_data = { custom_field: "custom_value" }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(custom_data)

        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("custom_field=custom_value")
        expect(result).to include("severity=INFO")
        expect(result).to include("pid=1234")
        expect(result).to include("timestamp=2022-07-17T18:43:15.123456")
      end
    end
  end
end

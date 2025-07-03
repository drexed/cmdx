# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::KeyValue do
  describe "#call" do
    let(:task) { mock_task(class: double(name: "TestTask")) }
    let(:time) { Time.utc(2022, 7, 17, 18, 43, 15.123456) }
    let(:serialized_data) do
      {
        index: 0,
        chain_id: "test-chain-id",
        type: "Task",
        class: "TestTask",
        id: "test-task-id",
        tags: [],
        state: "complete",
        status: "success",
        outcome: "success",
        metadata: {},
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
      end

      it "includes severity in key=value output" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("severity=INFO")
      end

      it "includes process ID in key=value output" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("pid=1234")
      end

      it "includes timestamp in key=value output" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("timestamp=2022-07-17T18:43:15.123456")
      end
    end

    context "with different severity levels" do
      it "formats DEBUG severity correctly" do
        result = described_class.new.call("DEBUG", time, task, "Debug message")

        expect(result).to include("severity=DEBUG")
      end

      it "formats WARN severity correctly" do
        result = described_class.new.call("WARN", time, task, "Warning message")

        expect(result).to include("severity=WARN")
      end

      it "formats ERROR severity correctly" do
        result = described_class.new.call("ERROR", time, task, "Error message")

        expect(result).to include("severity=ERROR")
      end

      it "formats FATAL severity correctly" do
        result = described_class.new.call("FATAL", time, task, "Fatal message")

        expect(result).to include("severity=FATAL")
      end
    end

    context "with serialized task data" do
      it "includes all serialized fields in key=value output" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("index=0")
        expect(result).to include("chain_id=test-chain-id")
        expect(result).to include("type=Task")
        expect(result).to include("class=TestTask")
        expect(result).to include("id=test-task-id")
        expect(result).to include("tags=[]")
        expect(result).to include("state=complete")
        expect(result).to include("status=success")
        expect(result).to include("outcome=success")
        expect(result).to include("metadata={}")
        expect(result).to include("runtime=15")
        expect(result).to include("origin=CMDx")
      end

      it "formats key=value pairs separated by spaces" do
        result = described_class.new.call("INFO", time, task, "Test message")
        content = result.chomp

        pairs = content.split
        expect(pairs.length).to be > 10
        expect(pairs).to all(include("="))
      end
    end

    context "with different message types" do
      it "handles string messages" do
        result = described_class.new.call("INFO", time, task, "String message")

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("=")
      end

      it "handles hash messages" do
        hash_message = { key: "value", number: 42 }
        result = described_class.new.call("INFO", time, task, hash_message)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("=")
      end

      it "handles array messages" do
        array_message = %w[item1 item2 item3]
        result = described_class.new.call("INFO", time, task, array_message)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("=")
      end

      it "handles nil messages" do
        result = described_class.new.call("INFO", time, task, nil)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect(result).to include("=")
      end
    end

    context "with time conversion" do
      it "converts time to UTC before formatting" do
        local_time = Time.new(2022, 7, 17, 20, 43, 15.123456)
        expected_utc = local_time.utc

        described_class.new.call("INFO", local_time, task, "Test message")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(expected_utc)
      end

      it "handles already UTC time correctly" do
        utc_time = Time.utc(2022, 7, 17, 18, 43, 15.123456)

        described_class.new.call("INFO", utc_time, task, "Test message")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(utc_time)
      end
    end

    context "with LoggerSerializer integration" do
      it "calls LoggerSerializer with correct parameters" do
        message = "Test message"

        described_class.new.call("INFO", time, task, message)

        expect(CMDx::LoggerSerializer).to have_received(:call).with("INFO", time, task, message)
      end

      it "uses LoggerSerializer return value in output" do
        custom_data = { custom_field: "custom_value" }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(custom_data)

        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("custom_field=custom_value")
      end
    end

    context "with single-line output requirement" do
      it "produces single-line output" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result.count("\n")).to eq(1)
        expect(result.chomp).not_to include("\n")
      end

      it "uses space separation between key=value pairs" do
        result = described_class.new.call("INFO", time, task, "Test message")
        content = result.chomp

        expect(content).to include(" ")
        expect(content.split.length).to be > 1
      end
    end

    context "with hash data processing" do
      it "converts hash to key=value format correctly" do
        hash_data = { key1: "value1", key2: "value2", key3: 123 }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(hash_data)

        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("key1=value1")
        expect(result).to include("key2=value2")
        expect(result).to include("key3=123")
      end

      it "preserves order of hash keys" do
        ordered_hash = { first: 1, second: 2, third: 3 }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(ordered_hash)

        result = described_class.new.call("INFO", time, task, "Test message")
        content = result.chomp

        first_pos = content.index("first=1")
        second_pos = content.index("second=2")
        third_pos = content.index("third=3")

        expect(first_pos).to be < second_pos
        expect(second_pos).to be < third_pos
      end
    end
  end
end

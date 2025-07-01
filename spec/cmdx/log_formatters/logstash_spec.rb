# frozen_string_literal: true

require "spec_helper"
require "socket"

RSpec.describe CMDx::LogFormatters::Logstash do
  describe "#call" do
    let(:task) { double("Task", class: double("TaskClass", name: "TestTask")) }
    let(:time) { Time.utc(2022, 7, 17, 18, 43, 15) }
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
      allow(CMDx::Utils::LogTimestamp).to receive(:call).and_return("2022-07-17T18:43:15")
      allow(Process).to receive(:pid).and_return(1234)
      allow(Socket).to receive(:gethostname).and_return("localhost")
    end

    context "with basic log entry" do
      it "returns Logstash-formatted JSON string with newline" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "includes @timestamp field in ISO8601 format" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["@timestamp"]).to eq("2022-07-17T18:43:15")
      end

      it "includes @version field" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["@version"]).to eq("1")
      end

      it "includes severity field with severity" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq("INFO")
      end

      it "includes origin field" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["origin"]).to eq("CMDx")
      end

      it "includes pid field" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["pid"]).to eq(1234)
      end
    end

    context "with different severity levels" do
      it "formats DEBUG severity correctly" do
        result = described_class.new.call("DEBUG", time, task, "Debug message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq("DEBUG")
      end

      it "formats WARN severity correctly" do
        result = described_class.new.call("WARN", time, task, "Warning message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq("WARN")
      end

      it "formats ERROR severity correctly" do
        result = described_class.new.call("ERROR", time, task, "Error message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq("ERROR")
      end

      it "formats FATAL severity correctly" do
        result = described_class.new.call("FATAL", time, task, "Fatal message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq("FATAL")
      end
    end

    context "with serialized task data" do
      it "includes flattened serialized fields" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["index"]).to eq(0)
        expect(parsed["chain_id"]).to eq("test-chain-id")
        expect(parsed["type"]).to eq("Task")
        expect(parsed["class"]).to eq("TestTask")
        expect(parsed["state"]).to eq("complete")
        expect(parsed["status"]).to eq("success")
        expect(parsed["outcome"]).to eq("success")
        expect(parsed["runtime"]).to eq(15)
        expect(parsed["origin"]).to eq("CMDx")
      end
    end

    context "with different message types" do
      it "handles string messages" do
        result = described_class.new.call("INFO", time, task, "String message")

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "handles hash messages" do
        hash_message = { key: "value", number: 42 }
        result = described_class.new.call("INFO", time, task, hash_message)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "handles array messages" do
        array_message = %w[item1 item2 item3]
        result = described_class.new.call("INFO", time, task, array_message)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "handles nil messages" do
        result = described_class.new.call("INFO", time, task, nil)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect { JSON.parse(result.chomp) }.not_to raise_error
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

        expect(CMDx::LoggerSerializer).to have_received(:call).with("INFO", time, task, message)
      end

      it "uses LoggerSerializer return value as flattened fields" do
        custom_data = { custom_field: "custom_value" }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(custom_data)

        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["custom_field"]).to eq("custom_value")
      end
    end

    context "with Logstash-specific structure" do
      it "includes required Logstash fields" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed).to have_key("@timestamp")
        expect(parsed).to have_key("@version")
        expect(parsed).to have_key("severity")
        expect(parsed).to have_key("pid")
      end

      it "produces single-line JSON without pretty formatting" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result.count("\n")).to eq(1)
        expect(result.chomp).not_to include("\n")
      end

      it "uses @ prefixed fields for Logstash metadata" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["@timestamp"]).to be_a(String)
        expect(parsed["@version"]).to be_a(String)
      end
    end

    context "with task metadata extraction" do
      it "extracts fields from serialized data" do
        custom_data = { class: "CustomTask", status: "failed", runtime: 42 }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(custom_data)

        result = described_class.new.call("ERROR", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["class"]).to eq("CustomTask")
        expect(parsed["status"]).to eq("failed")
        expect(parsed["runtime"]).to eq(42)
      end

      it "handles missing task metadata gracefully" do
        minimal_data = { index: 0 }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(minimal_data)

        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["index"]).to eq(0)
        expect(parsed["class"]).to be_nil
        expect(parsed["status"]).to be_nil
        expect(parsed["runtime"]).to be_nil
      end
    end

    context "with JSON structure validation" do
      it "produces valid JSON for all data types" do
        test_cases = [
          "string message",
          { hash: "data" },
          %w[array data],
          42,
          true,
          nil
        ]

        test_cases.each do |message|
          result = described_class.new.call("INFO", time, task, message)
          expect { JSON.parse(result.chomp) }.not_to raise_error
        end
      end

      it "maintains consistent field structure" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["@timestamp"]).to be_a(String)
        expect(parsed["@version"]).to be_a(String)
        expect(parsed["severity"]).to be_a(String)
        expect(parsed["pid"]).to be_a(Integer)
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyJson do
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
      it "returns pretty-formatted JSON string with newline" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "includes indentation for readability" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("  ")
        expect(result.lines.count).to be > 5
      end

      it "includes severity in pretty JSON output" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq("INFO")
      end

      it "includes process ID in pretty JSON output" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["pid"]).to eq(1234)
      end

      it "includes timestamp in pretty JSON output" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["timestamp"]).to eq("2022-07-17T18:43:15.123456")
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
      it "includes all serialized fields in pretty JSON output" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["index"]).to eq(0)
        expect(parsed["chain_id"]).to eq("test-chain-id")
        expect(parsed["type"]).to eq("Task")
        expect(parsed["class"]).to eq("TestTask")
        expect(parsed["id"]).to eq("test-task-id")
        expect(parsed["tags"]).to eq([])
        expect(parsed["state"]).to eq("complete")
        expect(parsed["status"]).to eq("success")
        expect(parsed["outcome"]).to eq("success")
        expect(parsed["metadata"]).to eq({})
        expect(parsed["runtime"]).to eq(15)
        expect(parsed["origin"]).to eq("CMDx")
      end

      it "merges serialized data with formatter metadata" do
        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed).to include(serialized_data.transform_keys(&:to_s))
        expect(parsed["severity"]).to eq("INFO")
        expect(parsed["pid"]).to eq(1234)
        expect(parsed["timestamp"]).to eq("2022-07-17T18:43:15.123456")
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
        parsed = JSON.parse(result.chomp)

        expect(parsed["custom_field"]).to eq("custom_value")
      end
    end

    context "with pretty formatting requirements" do
      it "produces multi-line JSON with indentation" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result.count("\n")).to be > 10
        expect(result).to include("  ")
        expect(result).to include("{\n")
        expect(result).to include("\n}")
      end

      it "formats nested objects with proper indentation" do
        nested_data = { nested_object: { key: "value" } }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(nested_data)

        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("  \"nested_object\": {\n")
        expect(result).to include("    \"key\": \"value\"\n")
        expect(result).to include("  }")
      end

      it "formats arrays with proper indentation" do
        array_data = { items: %w[item1 item2 item3] }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(array_data)

        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include("  \"items\": [\n")
        expect(result).to include("    \"item1\",\n")
        expect(result).to include("    \"item2\",\n")
        expect(result).to include("    \"item3\"\n")
        expect(result).to include("  ]")
      end
    end

    context "with JSON pretty_generate behavior" do
      it "uses JSON.pretty_generate for formatting" do
        test_data = { key: "value" }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(test_data)
        merged_data = test_data.merge(
          severity: "INFO",
          pid: 1234,
          timestamp: "2022-07-17T18:43:15.123456"
        )

        expect(JSON).to receive(:pretty_generate).with(merged_data).and_return(+"{}")

        described_class.new.call("INFO", time, task, "Test message")
      end

      it "preserves JSON structure and data types" do
        complex_data = {
          string: "text",
          number: 42,
          boolean: true,
          null_value: nil,
          array: [1, 2, 3],
          object: { nested: "value" }
        }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(complex_data)

        result = described_class.new.call("INFO", time, task, "Test message")
        parsed = JSON.parse(result.chomp)

        expect(parsed["string"]).to eq("text")
        expect(parsed["number"]).to eq(42)
        expect(parsed["boolean"]).to be(true)
        expect(parsed["null_value"]).to be_nil
        expect(parsed["array"]).to eq([1, 2, 3])
        expect(parsed["object"]).to eq({ "nested" => "value" })
      end
    end

    context "with human-readable output" do
      it "creates output suitable for development inspection" do
        result = described_class.new.call("INFO", time, task, "Test message")

        # Should be easy to read with proper spacing and line breaks
        expect(result).to match(/\{\n.*\n\}/m)
        expect(result.lines.length).to be > 5
        lines = result.lines
        expect(lines.first.strip).to eq("{")
        expect(lines.last.strip).to eq("}")
      end

      it "maintains consistent indentation throughout" do
        result = described_class.new.call("INFO", time, task, "Test message")
        lines = result.lines[1..-2] # Exclude opening and closing braces

        lines.each do |line|
          next if line.strip.empty?

          expect(line).to start_with("  ") # 2-space indentation
        end
      end

      it "includes proper JSON syntax with quotes and commas" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to include('": ')
        expect(result).to include('",')
        expect(result).to match(/"[^"]+":/)
      end
    end
  end
end

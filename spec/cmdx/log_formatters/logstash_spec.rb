# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Logstash do
  subject(:formatter) { described_class.new }

  describe "#call" do
    let(:severity) { "INFO" }
    let(:time) { Time.parse("2024-01-01T12:00:00Z") }
    let(:task) { double("task") }
    let(:mock_logger_serializer) { { message: "test", index: 1, chain_id: "abc123", type: "Task", class: "TestTask", id: "def456", tags: [], origin: "CMDx" } }

    before do
      allow(CMDx::LoggerSerializer).to receive(:call).and_return(mock_logger_serializer)
      allow(CMDx::Utils::LogTimestamp).to receive(:call).and_return("2024-01-01T12:00:00.000Z")
      allow(Process).to receive(:pid).and_return(12_345)
    end

    context "with string messages" do
      it "formats simple strings as Logstash JSON" do
        result = formatter.call(severity, time, task, "Hello World")
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include(
          "message" => "test",
          "severity" => "INFO",
          "pid" => 12_345,
          "@version" => "1",
          "@timestamp" => "2024-01-01T12:00:00.000Z",
          "origin" => "CMDx"
        )
        expect(result).to end_with("\n")
      end

      it "formats empty strings as Logstash JSON" do
        result = formatter.call(severity, time, task, "")
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats strings with special characters as Logstash JSON" do
        result = formatter.call(severity, time, task, "Hello\nWorld\t!")
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end
    end

    context "with numeric messages" do
      it "formats integers as Logstash JSON" do
        result = formatter.call(severity, time, task, 42)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats floats as Logstash JSON" do
        result = formatter.call(severity, time, task, 3.14)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats zero as Logstash JSON" do
        result = formatter.call(severity, time, task, 0)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats negative numbers as Logstash JSON" do
        result = formatter.call(severity, time, task, -123)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end
    end

    context "with boolean messages" do
      it "formats true as Logstash JSON" do
        result = formatter.call(severity, time, task, true)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats false as Logstash JSON" do
        result = formatter.call(severity, time, task, false)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end
    end

    context "with nil messages" do
      it "formats nil as Logstash JSON" do
        result = formatter.call(severity, time, task, nil)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end
    end

    context "with array messages" do
      it "formats simple arrays as Logstash JSON" do
        result = formatter.call(severity, time, task, [1, 2, 3])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats empty arrays as Logstash JSON" do
        result = formatter.call(severity, time, task, [])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats arrays with mixed types as Logstash JSON" do
        result = formatter.call(severity, time, task, [1, "string", true, nil])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats nested arrays as Logstash JSON" do
        result = formatter.call(severity, time, task, [[1, 2], [3, 4]])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end
    end

    context "with hash messages" do
      it "formats simple hashes as Logstash JSON" do
        result = formatter.call(severity, time, task, { a: 1, b: 2 })
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats empty hashes as Logstash JSON" do
        result = formatter.call(severity, time, task, {})
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats hashes with string keys as Logstash JSON" do
        result = formatter.call(severity, time, task, { "name" => "test", "value" => 42 })
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats nested hashes as Logstash JSON" do
        result = formatter.call(severity, time, task, { user: { name: "John", age: 30 } })
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end
    end

    context "with complex objects" do
      it "formats custom objects as Logstash JSON" do
        object = Object.new
        result = formatter.call(severity, time, task, object)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats structs as Logstash JSON" do
        person = Struct.new(:name, :age).new("John", 30)
        result = formatter.call(severity, time, task, person)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end

      it "formats symbols as Logstash JSON" do
        result = formatter.call(severity, time, task, :symbol)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO", "@version" => "1")
        expect(result).to end_with("\n")
      end
    end

    context "with required Logstash fields" do
      it "always includes severity in JSON output" do
        result = formatter.call("ERROR", time, task, "test")
        json_output = JSON.parse(result.chomp)

        expect(json_output["severity"]).to eq("ERROR")
      end

      it "always includes pid in JSON output" do
        result = formatter.call(severity, time, task, "test")
        json_output = JSON.parse(result.chomp)

        expect(json_output["pid"]).to eq(12_345)
      end

      it "always includes @version field set to '1'" do
        result = formatter.call(severity, time, task, "test")
        json_output = JSON.parse(result.chomp)

        expect(json_output["@version"]).to eq("1")
      end

      it "always includes @timestamp in JSON output" do
        result = formatter.call(severity, time, task, "test")
        json_output = JSON.parse(result.chomp)

        expect(json_output["@timestamp"]).to eq("2024-01-01T12:00:00.000Z")
      end

      it "calls Utils::LogTimestamp with UTC time" do
        utc_time = time.utc
        allow(time).to receive(:utc).and_return(utc_time)

        formatter.call(severity, time, task, "test")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(utc_time)
      end
    end

    context "with parameter handling" do
      it "passes all parameters to LoggerSerializer" do
        formatter.call(severity, time, task, "message")

        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task, "message")
      end

      it "handles different severity levels" do
        %w[DEBUG INFO WARN ERROR FATAL].each do |level|
          result = formatter.call(level, time, task, "message")
          json_output = JSON.parse(result.chomp)

          expect(json_output["severity"]).to eq(level)
        end
      end

      it "handles different time values" do
        time1 = Time.parse("2024-01-01T12:00:00Z")
        time2 = Time.parse("2024-12-31T23:59:59Z")

        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time1.utc).and_return("2024-01-01T12:00:00.000Z")
        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time2.utc).and_return("2024-12-31T23:59:59.000Z")

        result1 = formatter.call(severity, time1, task, "message")
        result2 = formatter.call(severity, time2, task, "message")

        json_output1 = JSON.parse(result1.chomp)
        json_output2 = JSON.parse(result2.chomp)

        expect(json_output1["@timestamp"]).to eq("2024-01-01T12:00:00.000Z")
        expect(json_output2["@timestamp"]).to eq("2024-12-31T23:59:59.000Z")
      end

      it "handles different task objects" do
        task1 = double("task1")
        task2 = double("task2")

        formatter.call(severity, time, task1, "message")
        formatter.call(severity, time, task2, "message")

        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task1, "message")
        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task2, "message")
      end

      it "handles nil severity parameter gracefully" do
        result = formatter.call(nil, time, task, "message")
        json_output = JSON.parse(result.chomp)

        expect(json_output["severity"]).to be_nil
        expect(json_output["pid"]).to eq(12_345)
        expect(json_output["@version"]).to eq("1")
        expect(json_output["@timestamp"]).to eq("2024-01-01T12:00:00.000Z")
      end
    end

    context "with JSON serialization errors" do
      it "allows JSON::GeneratorError to propagate" do
        # Create an object that can't be serialized to JSON
        problematic_object = Object.new
        def problematic_object.to_json(*_args)
          raise JSON::GeneratorError, "Cannot serialize"
        end

        allow(CMDx::LoggerSerializer).to receive(:call).and_return({ message: problematic_object })

        expect { formatter.call(severity, time, task, "test") }.to raise_error(JSON::GeneratorError)
      end
    end

    context "with output format" do
      it "outputs single line JSON with newline" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to end_with("\n")
        expect(result.count("\n")).to eq(1)
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "produces compact JSON without extra whitespace" do
        result = formatter.call(severity, time, task, { key: "value" })
        json_line = result.chomp

        expect(json_line).not_to include("  ") # No double spaces
        expect(json_line).not_to include("\n") # No internal newlines
        expect(json_line).not_to include("\t") # No tabs
      end

      it "merges LoggerSerializer output with Logstash fields" do
        result = formatter.call(severity, time, task, "test")
        json_output = JSON.parse(result.chomp)

        # Should contain LoggerSerializer fields
        expect(json_output).to include(
          "message" => "test",
          "index" => 1,
          "chain_id" => "abc123",
          "type" => "Task",
          "class" => "TestTask",
          "id" => "def456",
          "tags" => [],
          "origin" => "CMDx"
        )

        # Should also contain Logstash-specific fields
        expect(json_output).to include(
          "severity" => "INFO",
          "pid" => 12_345,
          "@version" => "1",
          "@timestamp" => "2024-01-01T12:00:00.000Z"
        )
      end
    end
  end

  describe "integration with tasks" do
    it "logs messages from task as Logstash JSON" do
      local_io = StringIO.new

      custom_task = create_simple_task(name: "CustomLogstashTask") do
        cmd_settings!(
          logger: Logger.new(local_io),
          log_formatter: CMDx::LogFormatters::Logstash.new # rubocop:disable RSpec/DescribedClass
        )

        def call
          logger.info("String message")
          logger.debug([])
          logger.warn(nil)
          logger.error({ error: "failed", "code" => 500 })
        end
      end

      custom_task.call
      logged_content = local_io.tap(&:rewind).read

      # Check that Logstash JSON output is present
      expect(logged_content).to include('"severity":"INFO"')
      expect(logged_content).to include('"severity":"DEBUG"')
      expect(logged_content).to include('"severity":"WARN"')
      expect(logged_content).to include('"severity":"ERROR"')

      # Check for Logstash-specific fields
      expect(logged_content).to include('"@version":"1"')
      expect(logged_content).to include('"@timestamp"')
      expect(logged_content).to include('"pid"')

      # Task result is logged as JSON
      expect(logged_content).to include('"class":"CustomLogstashTask')
    end
  end
end

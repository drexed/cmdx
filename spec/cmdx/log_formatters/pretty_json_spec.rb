# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyJson do
  subject(:formatter) { described_class.new }

  describe "#call" do
    let(:severity) { "INFO" }
    let(:time) { Time.parse("2024-01-01T12:00:00Z") }
    let(:task) { double("task") }
    let(:mock_logger_serializer) { { message: "test", index: 1, chain_id: "abc123", type: "Task", class: "TestTask", id: "def456", tags: [], origin: "CMDx" } }

    before do
      allow(CMDx::LoggerSerializer).to receive(:call).and_return(mock_logger_serializer)
      allow(CMDx::Utils::LogTimestamp).to receive(:call).and_return("2024-01-01T12:00:00.000000")
      allow(Process).to receive(:pid).and_return(12_345)
    end

    context "with string messages" do
      it "formats simple strings as pretty JSON" do
        result = formatter.call(severity, time, task, "Hello World")
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include(
          "message" => "test",
          "severity" => "INFO",
          "pid" => 12_345,
          "timestamp" => "2024-01-01T12:00:00.000000",
          "origin" => "CMDx"
        )
        expect(result).to end_with("\n")
      end

      it "formats empty strings as pretty JSON" do
        result = formatter.call(severity, time, task, "")
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats strings with special characters as pretty JSON" do
        result = formatter.call(severity, time, task, "Hello\nWorld\t!")
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with numeric messages" do
      it "formats integers as pretty JSON" do
        result = formatter.call(severity, time, task, 42)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats floats as pretty JSON" do
        result = formatter.call(severity, time, task, 3.14)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats zero as pretty JSON" do
        result = formatter.call(severity, time, task, 0)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats negative numbers as pretty JSON" do
        result = formatter.call(severity, time, task, -123)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with boolean messages" do
      it "formats true as pretty JSON" do
        result = formatter.call(severity, time, task, true)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats false as pretty JSON" do
        result = formatter.call(severity, time, task, false)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with nil messages" do
      it "formats nil as pretty JSON" do
        result = formatter.call(severity, time, task, nil)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with array messages" do
      it "formats simple arrays as pretty JSON" do
        result = formatter.call(severity, time, task, [1, 2, 3])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats empty arrays as pretty JSON" do
        result = formatter.call(severity, time, task, [])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats arrays with mixed types as pretty JSON" do
        result = formatter.call(severity, time, task, [1, "string", true, nil])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats nested arrays as pretty JSON" do
        result = formatter.call(severity, time, task, [[1, 2], [3, 4]])
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with hash messages" do
      it "formats simple hashes as pretty JSON" do
        result = formatter.call(severity, time, task, { a: 1, b: 2 })
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats empty hashes as pretty JSON" do
        result = formatter.call(severity, time, task, {})
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats hashes with string keys as pretty JSON" do
        result = formatter.call(severity, time, task, { "name" => "test", "value" => 42 })
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats nested hashes as pretty JSON" do
        result = formatter.call(severity, time, task, { user: { name: "John", age: 30 } })
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with complex objects" do
      it "formats custom objects as pretty JSON" do
        object = Object.new
        result = formatter.call(severity, time, task, object)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats structs as pretty JSON" do
        person = Struct.new(:name, :age).new("John", 30)
        result = formatter.call(severity, time, task, person)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end

      it "formats symbols as pretty JSON" do
        result = formatter.call(severity, time, task, :symbol)
        json_output = JSON.parse(result.chomp)

        expect(json_output).to include("severity" => "INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with required JSON fields" do
      it "always includes severity in pretty JSON output" do
        result = formatter.call("ERROR", time, task, "test")
        json_output = JSON.parse(result.chomp)

        expect(json_output["severity"]).to eq("ERROR")
      end

      it "always includes pid in pretty JSON output" do
        result = formatter.call(severity, time, task, "test")
        json_output = JSON.parse(result.chomp)

        expect(json_output["pid"]).to eq(12_345)
      end

      it "always includes timestamp in pretty JSON output" do
        result = formatter.call(severity, time, task, "test")
        json_output = JSON.parse(result.chomp)

        expect(json_output["timestamp"]).to eq("2024-01-01T12:00:00.000000")
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

        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time1.utc).and_return("2024-01-01T12:00:00.000000")
        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time2.utc).and_return("2024-12-31T23:59:59.000000")

        result1 = formatter.call(severity, time1, task, "message")
        result2 = formatter.call(severity, time2, task, "message")

        json_output1 = JSON.parse(result1.chomp)
        json_output2 = JSON.parse(result2.chomp)

        expect(json_output1["timestamp"]).to eq("2024-01-01T12:00:00.000000")
        expect(json_output2["timestamp"]).to eq("2024-12-31T23:59:59.000000")
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
        expect(json_output["timestamp"]).to eq("2024-01-01T12:00:00.000000")
      end
    end

    context "with JSON serialization errors" do
      it "allows JSON::GeneratorError to propagate" do
        # Create an object that can't be serialized to JSON
        problematic_object = Object.new
        def problematic_object.to_json(*args)
          raise JSON::GeneratorError, "Cannot serialize"
        end

        allow(CMDx::LoggerSerializer).to receive(:call).and_return({ message: problematic_object })

        expect { formatter.call(severity, time, task, "test") }.to raise_error(JSON::GeneratorError)
      end
    end

    context "with pretty JSON output format" do
      it "outputs multi-line pretty JSON with newline" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to end_with("\n")
        expect(result.count("\n")).to be > 1 # Pretty JSON has multiple lines
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "produces formatted JSON with proper indentation" do
        result = formatter.call(severity, time, task, { key: "value" })

        expect(result).to include("  ") # Contains indentation
        expect(result).to include("{\n") # Opening brace with newline
        expect(result).to include("\n}") # Closing brace with newline
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "formats nested structures with proper indentation" do
        nested_data = { user: { profile: { name: "John", settings: { theme: "dark" } } } }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(nested_data)

        result = formatter.call(severity, time, task, "test")

        expect(result).to include("    ") # Contains deeper indentation for nested objects
        expect(result.count("\n")).to be > 5 # Multiple lines for nested structure
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "maintains readability with complex arrays" do
        array_data = { items: [{ id: 1, name: "first" }, { id: 2, name: "second" }] }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(array_data)

        result = formatter.call(severity, time, task, "test")

        expect(result).to include("[\n") # Array with newline
        expect(result).to include("  {") # Indented array items
        expect { JSON.parse(result.chomp) }.not_to raise_error
      end
    end
  end

  describe "integration with tasks" do
    it "logs messages from task as pretty JSON" do
      local_io = StringIO.new

      custom_task = create_simple_task(name: "CustomPrettyJsonTask") do
        cmd_settings!(
          logger: Logger.new(local_io),
          log_formatter: CMDx::LogFormatters::PrettyJson.new # rubocop:disable RSpec/DescribedClass
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

      # Check that pretty JSON output is present
      expect(logged_content).to include('"severity": "INFO"')
      expect(logged_content).to include('"severity": "DEBUG"')
      expect(logged_content).to include('"severity": "WARN"')
      expect(logged_content).to include('"severity": "ERROR"')

      # Task result is logged as pretty JSON
      expect(logged_content).to include('"class": "CustomPrettyJsonTask"')

      # Verify it's actually pretty-formatted (has indentation)
      expect(logged_content).to include("  ") # Contains indentation
      expect(logged_content).to include("{\n") # Opening braces with newlines
    end
  end
end

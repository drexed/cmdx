# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyKeyValue do
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
      it "formats simple strings as key=value pairs" do
        result = formatter.call(severity, time, task, "Hello World")

        expect(result).to include("severity=INFO")
        expect(result).to include("pid=12345")
        expect(result).to include("timestamp=2024-01-01T12:00:00.000000")
        expect(result).to include("message=test")
        expect(result).to end_with("\n")
      end

      it "formats empty strings as key=value pairs" do
        result = formatter.call(severity, time, task, "")

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats strings with special characters as key=value pairs" do
        result = formatter.call(severity, time, task, "Hello\nWorld\t!")

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with numeric messages" do
      it "formats integers as key=value pairs" do
        result = formatter.call(severity, time, task, 42)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats floats as key=value pairs" do
        result = formatter.call(severity, time, task, 3.14)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats zero as key=value pairs" do
        result = formatter.call(severity, time, task, 0)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats negative numbers as key=value pairs" do
        result = formatter.call(severity, time, task, -123)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with boolean messages" do
      it "formats true as key=value pairs" do
        result = formatter.call(severity, time, task, true)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats false as key=value pairs" do
        result = formatter.call(severity, time, task, false)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with nil messages" do
      it "formats nil as key=value pairs" do
        result = formatter.call(severity, time, task, nil)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with array messages" do
      it "formats simple arrays as key=value pairs" do
        result = formatter.call(severity, time, task, [1, 2, 3])

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats empty arrays as key=value pairs" do
        result = formatter.call(severity, time, task, [])

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats arrays with mixed types as key=value pairs" do
        result = formatter.call(severity, time, task, [1, "string", true, nil])

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats nested arrays as key=value pairs" do
        result = formatter.call(severity, time, task, [[1, 2], [3, 4]])

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with hash messages" do
      it "formats simple hashes as key=value pairs" do
        result = formatter.call(severity, time, task, { a: 1, b: 2 })

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats empty hashes as key=value pairs" do
        result = formatter.call(severity, time, task, {})

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats hashes with string keys as key=value pairs" do
        result = formatter.call(severity, time, task, { "name" => "test", "value" => 42 })

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats nested hashes as key=value pairs" do
        result = formatter.call(severity, time, task, { user: { name: "John", age: 30 } })

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with complex objects" do
      it "formats custom objects as key=value pairs" do
        object = Object.new
        result = formatter.call(severity, time, task, object)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats structs as key=value pairs" do
        person = Struct.new(:name, :age).new("John", 30)
        result = formatter.call(severity, time, task, person)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end

      it "formats symbols as key=value pairs" do
        result = formatter.call(severity, time, task, :symbol)

        expect(result).to include("severity=INFO")
        expect(result).to end_with("\n")
      end
    end

    context "with required key=value fields" do
      it "always includes severity in output" do
        result = formatter.call("ERROR", time, task, "test")

        expect(result).to include("severity=ERROR")
      end

      it "always includes pid in output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("pid=12345")
      end

      it "always includes timestamp in output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("timestamp=2024-01-01T12:00:00.000000")
      end

      it "calls Utils::LogTimestamp with UTC time" do
        utc_time = time.utc
        allow(time).to receive(:utc).and_return(utc_time)

        formatter.call(severity, time, task, "test")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(utc_time)
      end
    end

    context "with parameter handling" do
      it "passes parameters to LoggerSerializer with ansi_colorize: true" do
        formatter.call(severity, time, task, "message")

        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task, "message", ansi_colorize: true)
      end

      it "handles different severity levels" do
        %w[DEBUG INFO WARN ERROR FATAL].each do |level|
          result = formatter.call(level, time, task, "message")

          expect(result).to include("severity=#{level}")
        end
      end

      it "handles different time values" do
        time1 = Time.parse("2024-01-01T12:00:00Z")
        time2 = Time.parse("2024-12-31T23:59:59Z")

        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time1.utc).and_return("2024-01-01T12:00:00.000000")
        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time2.utc).and_return("2024-12-31T23:59:59.000000")

        result1 = formatter.call(severity, time1, task, "message")
        result2 = formatter.call(severity, time2, task, "message")

        expect(result1).to include("timestamp=2024-01-01T12:00:00.000000")
        expect(result2).to include("timestamp=2024-12-31T23:59:59.000000")
      end

      it "handles different task objects" do
        task1 = double("task1")
        task2 = double("task2")

        formatter.call(severity, time, task1, "message")
        formatter.call(severity, time, task2, "message")

        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task1, "message", ansi_colorize: true)
        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task2, "message", ansi_colorize: true)
      end

      it "handles nil severity parameter gracefully" do
        result = formatter.call(nil, time, task, "message")

        expect(result).to include("severity=")
        expect(result).to include("pid=12345")
        expect(result).to include("timestamp=2024-01-01T12:00:00.000000")
      end
    end

    context "with output format" do
      it "outputs key=value pairs separated by spaces with newline" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("=")
        expect(result).to end_with("\n")
        expect(result.count("\n")).to eq(1)
      end

      it "formats all hash entries as key=value pairs" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("=")
        expect(result).not_to include("{")
        expect(result).not_to include("}")
        expect(result).not_to include('"')
      end
    end
  end

  describe "integration with tasks" do
    it "logs messages from task as key=value pairs" do
      local_io = StringIO.new

      custom_task = create_simple_task(name: "CustomKeyValueTask") do
        cmd_settings!(
          logger: Logger.new(local_io),
          log_formatter: CMDx::LogFormatters::PrettyKeyValue.new # rubocop:disable RSpec/DescribedClass
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

      # Check that pretty key value output is present
      expect(logged_content).to include("severity=INFO")
      expect(logged_content).to include("severity=DEBUG")
      expect(logged_content).to include("severity=WARN")
      expect(logged_content).to include("severity=ERROR")

      # Task result is logged as key value pairs
      expect(logged_content).to include("class=CustomKeyValueTask")

      # Verify it has ASCI colors
      expect(logged_content).to include("\e[0;32;49mcomplete\e[0m")
    end
  end
end

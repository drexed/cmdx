# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Line do
  subject(:formatter) { described_class.new }

  describe "#call" do
    let(:severity) { "INFO" }
    let(:time) { Time.parse("2024-01-01T12:00:00Z") }
    let(:task) { double("task", class: double("task_class", name: "TestTask")) }
    let(:mock_logger_serializer) { "test message" }

    before do
      allow(CMDx::LoggerSerializer).to receive(:call).and_return(mock_logger_serializer)
      allow(CMDx::Utils::LogTimestamp).to receive(:call).and_return("2024-01-01T12:00:00.000000")
      allow(Process).to receive(:pid).and_return(12_345)
    end

    context "with string messages" do
      it "formats simple strings as line" do
        result = formatter.call(severity, time, task, "Hello World")

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats empty strings as line" do
        result = formatter.call(severity, time, task, "")

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats strings with special characters as line" do
        result = formatter.call(severity, time, task, "Hello\nWorld\t!")

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end
    end

    context "with numeric messages" do
      it "formats integers as line" do
        result = formatter.call(severity, time, task, 42)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats floats as line" do
        result = formatter.call(severity, time, task, 3.14)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats zero as line" do
        result = formatter.call(severity, time, task, 0)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats negative numbers as line" do
        result = formatter.call(severity, time, task, -123)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end
    end

    context "with boolean messages" do
      it "formats true as line" do
        result = formatter.call(severity, time, task, true)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats false as line" do
        result = formatter.call(severity, time, task, false)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end
    end

    context "with nil messages" do
      it "formats nil as line" do
        result = formatter.call(severity, time, task, nil)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end
    end

    context "with array messages" do
      it "formats simple arrays as line" do
        result = formatter.call(severity, time, task, [1, 2, 3])

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats empty arrays as line" do
        result = formatter.call(severity, time, task, [])

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats arrays with mixed types as line" do
        result = formatter.call(severity, time, task, [1, "string", true, nil])

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats nested arrays as line" do
        result = formatter.call(severity, time, task, [[1, 2], [3, 4]])

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end
    end

    context "with hash messages" do
      let(:mock_logger_serializer) { { key1: "value1", key2: "value2" } }

      it "formats simple hashes as key=value pairs" do
        result = formatter.call(severity, time, task, { a: 1, b: 2 })

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: key1=value1 key2=value2\n")
      end

      it "formats empty hashes as line" do
        allow(CMDx::LoggerSerializer).to receive(:call).and_return({})
        result = formatter.call(severity, time, task, {})

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: \n")
      end

      it "formats hashes with string keys as key=value pairs" do
        allow(CMDx::LoggerSerializer).to receive(:call).and_return({ "name" => "test", "value" => 42 })
        result = formatter.call(severity, time, task, { "name" => "test", "value" => 42 })

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: name=test value=42\n")
      end

      it "formats nested hashes as key=value pairs" do
        nested_hash = { user: { name: "John", age: 30 } }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(nested_hash)
        result = formatter.call(severity, time, task, nested_hash)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: user={name: \"John\", age: 30}\n")
      end
    end

    context "with complex objects" do
      it "formats custom objects as line" do
        object = Object.new
        result = formatter.call(severity, time, task, object)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats structs as line" do
        person = Struct.new(:name, :age).new("John", 30)
        result = formatter.call(severity, time, task, person)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end

      it "formats symbols as line" do
        result = formatter.call(severity, time, task, :symbol)

        expect(result).to eq("I, [2024-01-01T12:00:00.000000 #12345] INFO -- TestTask: test message\n")
      end
    end

    context "with required line fields" do
      it "includes severity initial in line output" do
        result = formatter.call("ERROR", time, task, "test")

        expect(result).to start_with("E, [")
        expect(result).to include("] ERROR -- ")
      end

      it "includes pid in line output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("#12345]")
      end

      it "includes timestamp in line output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("[2024-01-01T12:00:00.000000 #")
      end

      it "includes task class name in line output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("-- TestTask:")
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

          expect(result).to include("] #{level} -- ")
          expect(result).to start_with("#{level[0]}, [")
        end
      end

      it "handles different time values" do
        time1 = Time.parse("2024-01-01T12:00:00Z")
        time2 = Time.parse("2024-12-31T23:59:59Z")

        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time1.utc).and_return("2024-01-01T12:00:00.000000")
        allow(CMDx::Utils::LogTimestamp).to receive(:call).with(time2.utc).and_return("2024-12-31T23:59:59.000000")

        result1 = formatter.call(severity, time1, task, "message")
        result2 = formatter.call(severity, time2, task, "message")

        expect(result1).to include("2024-01-01T12:00:00.000000")
        expect(result2).to include("2024-12-31T23:59:59.000000")
      end

      it "handles different task objects" do
        task1 = double("task1", class: double("task_class1", name: "Task1"))
        task2 = double("task2", class: double("task_class2", name: "Task2"))

        result1 = formatter.call(severity, time, task1, "message")
        result2 = formatter.call(severity, time, task2, "message")

        expect(result1).to include("-- Task1:")
        expect(result2).to include("-- Task2:")
      end

      it "handles empty severity parameter gracefully" do
        result = formatter.call("", time, task, "message")

        expect(result).to include("[2024-01-01T12:00:00.000000 #12345]")
        expect(result).to include("-- TestTask:")
        expect(result).to end_with("test message\n")
        expect(result).to start_with(", [") # empty severity[0]
      end
    end

    context "with output format" do
      it "outputs single line with newline" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to end_with("\n")
        expect(result.count("\n")).to eq(1)
      end

      it "follows traditional log format structure" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to match(/^[A-Z], \[.+ #\d+\] [A-Z]+ -- .+: .+\n$/)
      end
    end
  end

  describe "integration with tasks" do
    it "logs messages from task as line format" do
      local_io = StringIO.new

      custom_task = create_simple_task(name: "CustomLineTask") do
        cmd_settings!(
          logger: Logger.new(local_io),
          log_formatter: CMDx::LogFormatters::Line.new # rubocop:disable RSpec/DescribedClass
        )

        def call
          logger.info("String message")
          logger.debug("Debug info")
          logger.warn("Warning message")
          logger.error("Error occurred")
        end
      end

      custom_task.call
      logged_content = local_io.tap(&:rewind).read

      expect(logged_content).to include("I, [")
      expect(logged_content).to include("] INFO -- CustomLineTask:")
      expect(logged_content).to include("D, [")
      expect(logged_content).to include("] DEBUG -- CustomLineTask:")
      expect(logged_content).to include("W, [")
      expect(logged_content).to include("] WARN -- CustomLineTask:")
      expect(logged_content).to include("E, [")
      expect(logged_content).to include("] ERROR -- CustomLineTask:")
    end
  end
end

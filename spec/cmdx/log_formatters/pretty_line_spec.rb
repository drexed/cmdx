# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::PrettyLine do
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
      allow(CMDx::LoggerAnsi).to receive(:call).and_return("ANSI_FORMATTED")
    end

    context "with string messages" do
      it "formats simple strings as colorized line" do
        result = formatter.call(severity, time, task, "Hello World")

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats empty strings as colorized line" do
        result = formatter.call(severity, time, task, "")

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats strings with special characters as colorized line" do
        result = formatter.call(severity, time, task, "Hello\nWorld\t!")

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end
    end

    context "with numeric messages" do
      it "formats integers as colorized line" do
        result = formatter.call(severity, time, task, 42)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats floats as colorized line" do
        result = formatter.call(severity, time, task, 3.14)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats zero as colorized line" do
        result = formatter.call(severity, time, task, 0)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats negative numbers as colorized line" do
        result = formatter.call(severity, time, task, -123)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end
    end

    context "with boolean messages" do
      it "formats true as colorized line" do
        result = formatter.call(severity, time, task, true)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats false as colorized line" do
        result = formatter.call(severity, time, task, false)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end
    end

    context "with nil messages" do
      it "formats nil as colorized line" do
        result = formatter.call(severity, time, task, nil)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end
    end

    context "with array messages" do
      it "formats simple arrays as colorized line" do
        result = formatter.call(severity, time, task, [1, 2, 3])

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats empty arrays as colorized line" do
        result = formatter.call(severity, time, task, [])

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats arrays with mixed types as colorized line" do
        result = formatter.call(severity, time, task, [1, "string", true, nil])

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats nested arrays as colorized line" do
        result = formatter.call(severity, time, task, [[1, 2], [3, 4]])

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end
    end

    context "with hash messages" do
      it "formats simple hashes as colorized line" do
        result = formatter.call(severity, time, task, { a: 1, b: 2 })

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats empty hashes as colorized line" do
        result = formatter.call(severity, time, task, {})

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats hashes with string keys as colorized line" do
        result = formatter.call(severity, time, task, { "name" => "test", "value" => 42 })

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats nested hashes as colorized line" do
        result = formatter.call(severity, time, task, { user: { name: "John", age: 30 } })

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end
    end

    context "with complex objects" do
      it "formats custom objects as colorized line" do
        object = Object.new
        result = formatter.call(severity, time, task, object)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats structs as colorized line" do
        person = Struct.new(:name, :age).new("John", 30)
        result = formatter.call(severity, time, task, person)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end

      it "formats symbols as colorized line" do
        result = formatter.call(severity, time, task, :symbol)

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: test message\n")
      end
    end

    context "with ANSI colorization" do
      it "applies ANSI coloring to severity letter" do
        formatter.call(severity, time, task, "test")

        expect(CMDx::LoggerAnsi).to have_received(:call).with("I")
      end

      it "applies ANSI coloring to full severity string" do
        formatter.call(severity, time, task, "test")

        expect(CMDx::LoggerAnsi).to have_received(:call).with("INFO")
      end

      it "handles different severity levels" do
        %w[DEBUG INFO WARN ERROR FATAL].each do |level|
          formatter.call(level, time, task, "message")

          expect(CMDx::LoggerAnsi).to have_received(:call).with(level[0])
          expect(CMDx::LoggerAnsi).to have_received(:call).with(level)
        end
      end
    end

    context "with timestamp handling" do
      it "calls Utils::LogTimestamp with UTC time" do
        utc_time = time.utc
        allow(time).to receive(:utc).and_return(utc_time)

        formatter.call(severity, time, task, "test")

        expect(CMDx::Utils::LogTimestamp).to have_received(:call).with(utc_time)
      end

      it "includes timestamp in output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("2024-01-01T12:00:00.000000")
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
    end

    context "with process ID inclusion" do
      it "includes process ID in output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("#12345")
      end

      it "handles different process IDs" do
        allow(Process).to receive(:pid).and_return(54_321)
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("#54321")
      end
    end

    context "with task class name" do
      it "includes task class name in output" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to include("TestTask:")
      end

      it "handles different task classes" do
        other_task = double("other_task", class: double("other_class", name: "OtherTask"))
        result = formatter.call(severity, time, other_task, "test")

        expect(result).to include("OtherTask:")
      end
    end

    context "with parameter handling" do
      it "passes parameters to LoggerSerializer with ansi_colorize: true" do
        formatter.call(severity, time, task, "message")

        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task, "message", ansi_colorize: true)
      end

      it "handles different task objects" do
        task1 = double("task1", class: double("class1", name: "Task1"))
        task2 = double("task2", class: double("class2", name: "Task2"))

        formatter.call(severity, time, task1, "message")
        formatter.call(severity, time, task2, "message")

        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task1, "message", ansi_colorize: true)
        expect(CMDx::LoggerSerializer).to have_received(:call).with(severity, time, task2, "message", ansi_colorize: true)
      end

      it "handles nil severity parameter gracefully" do
        allow(CMDx::LoggerAnsi).to receive(:call).with(nil).and_return("ANSI_NIL")

        expect { formatter.call(nil, time, task, "message") }.to raise_error(NoMethodError)
      end
    end

    context "with hash message serialization" do
      it "converts hash messages to key=value format" do
        hash_message = { error: "failed", code: 500 }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(hash_message)

        result = formatter.call(severity, time, task, "test")

        expect(result).to include("error=failed code=500")
      end

      it "handles empty hash messages" do
        allow(CMDx::LoggerSerializer).to receive(:call).and_return({})

        result = formatter.call(severity, time, task, "test")

        expect(result).to eq("ANSI_FORMATTED, [2024-01-01T12:00:00.000000 #12345] ANSI_FORMATTED -- TestTask: \n")
      end

      it "handles hash with string keys" do
        hash_message = { "status" => "success", "count" => 42 }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(hash_message)

        result = formatter.call(severity, time, task, "test")

        expect(result).to include("status=success count=42")
      end

      it "handles hash with mixed key types" do
        hash_message = { status: "success", "count" => 42 }
        allow(CMDx::LoggerSerializer).to receive(:call).and_return(hash_message)

        result = formatter.call(severity, time, task, "test")

        expect(result).to include("status=success count=42")
      end
    end

    context "with output format" do
      it "outputs traditional log line format with newline" do
        result = formatter.call(severity, time, task, "test")

        expect(result).to match(/^.+, \[.+ #\d+\] .+ -- .+: .+\n$/)
        expect(result).to end_with("\n")
        expect(result.count("\n")).to eq(1)
      end

      it "maintains consistent structure across different severities" do
        %w[DEBUG INFO WARN ERROR FATAL].each do |level|
          result = formatter.call(level, time, task, "message")

          expect(result).to match(/^.+, \[.+ #\d+\] .+ -- .+: .+\n$/)
        end
      end
    end
  end

  describe "integration with tasks" do
    it "logs messages from task in colorized line format" do
      local_io = StringIO.new

      custom_task = create_simple_task(name: "CustomLineTask") do
        cmd_settings!(
          logger: Logger.new(local_io),
          log_formatter: CMDx::LogFormatters::PrettyLine.new # rubocop:disable RSpec/DescribedClass
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

      # Check that pretty line output is present (using regex to handle ANSI codes)
      expect(logged_content).to match(/INFO.*-- CustomLineTask:/)
      expect(logged_content).to match(/DEBUG.*-- CustomLineTask:/)
      expect(logged_content).to match(/WARN.*-- CustomLineTask:/)
      expect(logged_content).to match(/ERROR.*-- CustomLineTask:/)

      # Task result includes class name
      expect(logged_content).to include("CustomLineTask:")

      # Verify it has ANSI colors
      expect(logged_content).to include("\e[")
    end
  end
end

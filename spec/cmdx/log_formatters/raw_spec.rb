# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Raw do
  subject(:formatter) { described_class.new }

  describe "#call" do
    let(:severity) { "INFO" }
    let(:time) { Time.now }
    let(:task) { double("task") }

    context "with string messages" do
      it "formats simple strings" do
        result = formatter.call(severity, time, task, "Hello World")

        expect(result).to eq("\"Hello World\"\n")
      end

      it "formats empty strings" do
        result = formatter.call(severity, time, task, "")

        expect(result).to eq("\"\"\n")
      end

      it "formats strings with special characters" do
        result = formatter.call(severity, time, task, "Hello\nWorld\t!")

        expect(result).to eq("\"Hello\\nWorld\\t!\"\n")
      end

      it "formats strings with quotes" do
        result = formatter.call(severity, time, task, 'Say "Hello"')

        expect(result).to eq("\"Say \\\"Hello\\\"\"\n")
      end
    end

    context "with numeric messages" do
      it "formats integers" do
        result = formatter.call(severity, time, task, 42)

        expect(result).to eq("42\n")
      end

      it "formats floats" do
        result = formatter.call(severity, time, task, 3.14)

        expect(result).to eq("3.14\n")
      end

      it "formats zero" do
        result = formatter.call(severity, time, task, 0)

        expect(result).to eq("0\n")
      end

      it "formats negative numbers" do
        result = formatter.call(severity, time, task, -123)

        expect(result).to eq("-123\n")
      end
    end

    context "with boolean messages" do
      it "formats true" do
        result = formatter.call(severity, time, task, true)

        expect(result).to eq("true\n")
      end

      it "formats false" do
        result = formatter.call(severity, time, task, false)

        expect(result).to eq("false\n")
      end
    end

    context "with nil messages" do
      it "formats nil" do
        result = formatter.call(severity, time, task, nil)

        expect(result).to eq("nil\n")
      end
    end

    context "with array messages" do
      it "formats simple arrays" do
        result = formatter.call(severity, time, task, [1, 2, 3])

        expect(result).to eq("[1, 2, 3]\n")
      end

      it "formats empty arrays" do
        result = formatter.call(severity, time, task, [])

        expect(result).to eq("[]\n")
      end

      it "formats arrays with mixed types" do
        result = formatter.call(severity, time, task, [1, "string", true, nil])

        expect(result).to eq("[1, \"string\", true, nil]\n")
      end

      it "formats nested arrays" do
        result = formatter.call(severity, time, task, [[1, 2], [3, 4]])

        expect(result).to eq("[[1, 2], [3, 4]]\n")
      end
    end

    context "with hash messages" do
      it "formats simple hashes" do
        result = formatter.call(severity, time, task, { a: 1, b: 2 })

        expect(result).to eq("{a: 1, b: 2}\n")
      end

      it "formats empty hashes" do
        result = formatter.call(severity, time, task, {})

        expect(result).to eq("{}\n")
      end

      it "formats hashes with string keys" do
        result = formatter.call(severity, time, task, { "name" => "test", "value" => 42 })

        expect(result).to eq("{\"name\" => \"test\", \"value\" => 42}\n")
      end

      it "formats nested hashes" do
        result = formatter.call(severity, time, task, { user: { name: "John", age: 30 } })

        expect(result).to eq("{user: {name: \"John\", age: 30}}\n")
      end
    end

    context "with complex objects" do
      it "formats custom objects" do
        object = Object.new
        result = formatter.call(severity, time, task, object)

        expect(result).to match(/^#<Object:0x[0-9a-f]+>\n$/)
      end

      it "formats structs" do
        person = Struct.new(:name, :age).new("John", 30)
        result = formatter.call(severity, time, task, person)

        expect(result).to match(/^#<struct.*name="John", age=30>\n$/)
      end

      it "formats symbols" do
        result = formatter.call(severity, time, task, :symbol)

        expect(result).to eq(":symbol\n")
      end

      it "formats ranges" do
        result = formatter.call(severity, time, task, 1..10)

        expect(result).to eq("1..10\n")
      end
    end

    context "with parameter handling" do
      it "ignores severity parameter" do
        result1 = formatter.call("DEBUG", time, task, "message")
        result2 = formatter.call("ERROR", time, task, "message")

        expect(result1).to eq(result2)
        expect(result1).to eq("\"message\"\n")
      end

      it "ignores time parameter" do
        time1 = Time.now
        time2 = Time.now + 3600
        result1 = formatter.call(severity, time1, task, "message")
        result2 = formatter.call(severity, time2, task, "message")

        expect(result1).to eq(result2)
        expect(result1).to eq("\"message\"\n")
      end

      it "ignores task parameter" do
        task1 = double("task1")
        task2 = double("task2")
        result1 = formatter.call(severity, time, task1, "message")
        result2 = formatter.call(severity, time, task2, "message")

        expect(result1).to eq(result2)
        expect(result1).to eq("\"message\"\n")
      end

      it "handles nil parameters for severity, time, and task" do
        result = formatter.call(nil, nil, nil, "message")

        expect(result).to eq("\"message\"\n")
      end
    end
  end

  describe "integration with tasks" do
    it "logs messages from task" do
      local_io = StringIO.new

      custom_task = create_simple_task(name: "CustomRawTask") do
        cmd_settings!(
          logger: Logger.new(local_io),
          log_formatter: CMDx::LogFormatters::Raw.new # rubocop:disable RSpec/DescribedClass
        )

        def call
          logger.info("String message")
          logger.debug(42)
          logger.warn(true)
          logger.error({ error: "failed", code: 500 })
        end
      end

      custom_task.call
      logged_content = local_io.tap(&:rewind).read

      expect(logged_content).to include("\"String message\"\n")
      expect(logged_content).to include("42\n")
      expect(logged_content).to include("true\n")
      expect(logged_content).to include("{error: \"failed\", code: 500}\n")

      # Task result is logged
      expect(logged_content).to include("#<CMDx::Result:")
    end
  end
end

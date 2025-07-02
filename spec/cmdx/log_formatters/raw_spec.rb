# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Raw do
  describe "#call" do
    let(:task) { mock_task(class: double(name: "TestTask")) }
    let(:time) { Time.utc(2022, 7, 17, 18, 43, 15.123456) }

    context "with basic functionality" do
      it "returns message inspect with newline" do
        result = described_class.new.call("INFO", time, task, "Test message")

        expect(result).to eq("\"Test message\"\n")
      end

      it "ignores severity parameter" do
        result1 = described_class.new.call("INFO", time, task, "message")
        result2 = described_class.new.call("ERROR", time, task, "message")

        expect(result1).to eq(result2)
      end

      it "ignores time parameter" do
        time1 = Time.utc(2022, 1, 1)
        time2 = Time.utc(2023, 12, 31)

        result1 = described_class.new.call("INFO", time1, task, "message")
        result2 = described_class.new.call("INFO", time2, task, "message")

        expect(result1).to eq(result2)
      end

      it "ignores task parameter" do
        task1 = mock_task
        task2 = mock_task

        result1 = described_class.new.call("INFO", time, task1, "message")
        result2 = described_class.new.call("INFO", time, task2, "message")

        expect(result1).to eq(result2)
      end
    end

    context "with different message types" do
      it "handles string messages" do
        result = described_class.new.call("INFO", time, task, "String message")

        expect(result).to eq("\"String message\"\n")
      end

      it "handles hash messages" do
        hash_message = { key: "value", number: 42 }
        result = described_class.new.call("INFO", time, task, hash_message)

        expect(result).to eq("{key: \"value\", number: 42}\n")
      end

      it "handles array messages" do
        array_message = %w[item1 item2 item3]
        result = described_class.new.call("INFO", time, task, array_message)

        expect(result).to eq("[\"item1\", \"item2\", \"item3\"]\n")
      end

      it "handles nil messages" do
        result = described_class.new.call("INFO", time, task, nil)

        expect(result).to eq("nil\n")
      end

      it "handles numeric messages" do
        result = described_class.new.call("INFO", time, task, 42)

        expect(result).to eq("42\n")
      end

      it "handles symbol messages" do
        result = described_class.new.call("INFO", time, task, :symbol)

        expect(result).to eq(":symbol\n")
      end
    end

    context "with complex data structures" do
      it "handles nested hashes" do
        nested_hash = { outer: { inner: "value" } }
        result = described_class.new.call("INFO", time, task, nested_hash)

        expect(result).to eq("{outer: {inner: \"value\"}}\n")
      end

      it "handles nested arrays" do
        nested_array = [%w[a b], %w[c d]]
        result = described_class.new.call("INFO", time, task, nested_array)

        expect(result).to eq("[[\"a\", \"b\"], [\"c\", \"d\"]]\n")
      end

      it "handles mixed data structures" do
        mixed_data = { array: [1, 2, 3], hash: { key: "value" }, string: "text" }
        result = described_class.new.call("INFO", time, task, mixed_data)

        expect(result).to eq("{array: [1, 2, 3], hash: {key: \"value\"}, string: \"text\"}\n")
      end
    end

    context "with special characters" do
      it "handles strings with newlines" do
        multiline_string = "Line 1\nLine 2\nLine 3"
        result = described_class.new.call("INFO", time, task, multiline_string)

        expect(result).to eq("\"Line 1\\nLine 2\\nLine 3\"\n")
      end

      it "handles strings with quotes" do
        quoted_string = 'String with "quotes" and \'apostrophes\''
        result = described_class.new.call("INFO", time, task, quoted_string)

        expect(result).to eq("\"String with \\\"quotes\\\" and 'apostrophes'\"\n")
      end

      it "handles strings with unicode characters" do
        unicode_string = "Hello 世界 🌍"
        result = described_class.new.call("INFO", time, task, unicode_string)

        expect(result).to eq("\"Hello 世界 🌍\"\n")
      end

      it "handles empty strings" do
        result = described_class.new.call("INFO", time, task, "")

        expect(result).to eq("\"\"\n")
      end
    end

    context "with output format requirements" do
      it "always ends with newline" do
        test_messages = ["string", 42, [], {}]

        test_messages.each do |message|
          result = described_class.new.call("INFO", time, task, message)
          expect(result).to end_with("\n")
        end
      end

      it "only contains inspect output and newline" do
        message = "test message"
        result = described_class.new.call("INFO", time, task, message)

        expect(result).to eq("#{message.inspect}\n")
        expect(result.count("\n")).to eq(1)
      end

      it "does not include any formatting metadata" do
        result = described_class.new.call("ERROR", time, task, "error message")

        expect(result).not_to include("ERROR")
        expect(result).not_to include("TestTask")
        expect(result).not_to include("2022-07-17")
        expect(result).not_to include("1234")
      end
    end

    context "with Ruby inspect behavior" do
      it "preserves exact inspect output format" do
        regex = /test.*pattern/
        result = described_class.new.call("INFO", time, task, regex)

        expect(result).to eq("#{regex.inspect}\n")
      end
    end

    context "with edge cases" do
      it "handles very large data structures" do
        large_array = (1..100).to_a
        result = described_class.new.call("INFO", time, task, large_array)

        expect(result).to eq("#{large_array.inspect}\n")
      end

      it "handles circular references gracefully" do
        hash = {}
        hash[:self] = hash

        result = described_class.new.call("INFO", time, task, hash)

        expect(result).to be_a(String)
        expect(result).to end_with("\n")
      end

      it "handles frozen objects" do
        frozen_string = "frozen"
        result = described_class.new.call("INFO", time, task, frozen_string)

        expect(result).to eq("\"frozen\"\n")
      end
    end
  end
end

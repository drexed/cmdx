# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Raw, type: :unit do
  subject(:formatter) { described_class.new }

  let(:severity) { "INFO" }
  let(:time) { Time.new(2023, 12, 15, 10, 30, 45.123454) }
  let(:progname) { "TestApp" }
  let(:message) { "Test message" }

  describe "#call" do
    context "with typical log parameters" do
      it "returns message with newline" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to eq("Test message\n")
      end

      it "ends with newline" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to end_with("\n")
      end

      it "ignores severity parameter" do
        result1 = formatter.call("DEBUG", time, progname, message)
        result2 = formatter.call("FATAL", time, progname, message)

        expect(result1).to eq(result2)
        expect(result1).to eq("Test message\n")
      end

      it "ignores time parameter" do
        time1 = Time.new(2020, 1, 1)
        time2 = Time.new(2030, 12, 31)
        result1 = formatter.call(severity, time1, progname, message)
        result2 = formatter.call(severity, time2, progname, message)

        expect(result1).to eq(result2)
        expect(result1).to eq("Test message\n")
      end

      it "ignores progname parameter" do
        result1 = formatter.call(severity, time, "App1", message)
        result2 = formatter.call(severity, time, "App2", message)

        expect(result1).to eq(result2)
        expect(result1).to eq("Test message\n")
      end
    end

    context "with nil values" do
      it "handles nil severity" do
        result = formatter.call(nil, time, progname, message)

        expect(result).to eq("Test message\n")
      end

      it "handles nil time" do
        result = formatter.call(severity, nil, progname, message)

        expect(result).to eq("Test message\n")
      end

      it "handles nil progname" do
        result = formatter.call(severity, time, nil, message)

        expect(result).to eq("Test message\n")
      end

      it "handles nil message" do
        result = formatter.call(severity, time, progname, nil)

        expect(result).to eq("\n")
      end
    end

    context "with special characters in message" do
      it "handles newlines in message" do
        message_with_newline = "Line 1\nLine 2"

        result = formatter.call(severity, time, progname, message_with_newline)

        expect(result).to eq("Line 1\nLine 2\n")
      end

      it "handles unicode characters in message" do
        unicode_message = "Test message with émojis 🚀"

        result = formatter.call(severity, time, progname, unicode_message)

        expect(result).to eq("Test message with émojis 🚀\n")
      end

      it "handles backslashes in message" do
        message_with_backslash = "C:\\Windows\\Path"

        result = formatter.call(severity, time, progname, message_with_backslash)

        expect(result).to eq("C:\\Windows\\Path\n")
      end

      it "handles quotes in message" do
        message_with_quotes = 'Message with "quotes" and \'apostrophes\''

        result = formatter.call(severity, time, progname, message_with_quotes)

        expect(result).to eq("Message with \"quotes\" and 'apostrophes'\n")
      end
    end

    context "with complex objects as message" do
      it "handles hash messages" do
        hash_message = { "state" => "complete", "status" => "success" }

        result = formatter.call(severity, time, progname, hash_message)

        expect(result).to eq("{\"state\" => \"complete\", \"status\" => \"success\"}\n")
      end

      it "handles array messages" do
        array_message = %w[item1 item2 item3]

        result = formatter.call(severity, time, progname, array_message)

        expect(result).to eq("[\"item1\", \"item2\", \"item3\"]\n")
      end

      it "handles numeric messages" do
        numeric_message = 42

        result = formatter.call(severity, time, progname, numeric_message)

        expect(result).to eq("42\n")
      end

      it "handles boolean messages" do
        boolean_message = true

        result = formatter.call(severity, time, progname, boolean_message)

        expect(result).to eq("true\n")
      end

      it "handles symbol messages" do
        symbol_message = :success

        result = formatter.call(severity, time, progname, symbol_message)

        expect(result).to eq("success\n")
      end
    end

    context "with empty string values" do
      it "handles empty string message" do
        result = formatter.call(severity, time, progname, "")

        expect(result).to eq("\n")
      end

      it "handles empty string for other parameters" do
        result = formatter.call("", nil, "", message)

        expect(result).to eq("Test message\n")
      end
    end

    context "with very long strings" do
      it "handles large messages without truncation" do
        large_message = "x" * 10_000

        result = formatter.call(severity, time, progname, large_message)

        expect(result).to eq("#{'x' * 10_000}\n")
        expect(result.length).to eq(10_001)
      end
    end

    context "with different message types" do
      it "handles string interpolation correctly" do
        interpolated_message = "Value is 42"

        result = formatter.call(severity, time, progname, interpolated_message)

        expect(result).to eq("Value is 42\n")
      end

      it "handles frozen strings" do
        frozen_message = "Frozen message"

        result = formatter.call(severity, time, progname, frozen_message)

        expect(result).to eq("Frozen message\n")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::JSON do
  subject(:formatter) { described_class.new }

  let(:severity) { "INFO" }
  let(:time) { Time.new(2023, 12, 15, 10, 30, 45.123454) }
  let(:progname) { "TestApp" }
  let(:message) { "Test message" }

  describe "#call" do
    context "with typical log parameters" do
      it "returns properly formatted JSON with newline" do
        result = formatter.call(severity, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed).to eq(
          {
            "severity" => "INFO",
            "timestamp" => "2023-12-15T10:30:45.123454Z",
            "progname" => "TestApp",
            "pid" => Process.pid,
            "message" => "Test message"
          }
        )
        expect(result).to end_with("\n")
      end

      it "includes current process PID" do
        result = formatter.call(severity, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["pid"]).to eq(Process.pid)
      end

      it "formats timestamp in UTC ISO8601 with microseconds" do
        result = formatter.call(severity, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["timestamp"]).to eq("2023-12-15T10:30:45.123454Z")
      end
    end

    context "with different severity levels" do
      %w[DEBUG INFO WARN ERROR FATAL].each do |level|
        it "handles #{level} severity" do
          result = formatter.call(level, time, progname, message)
          parsed = JSON.parse(result.chomp)

          expect(parsed["severity"]).to eq(level)
        end
      end
    end

    context "with different time zones" do
      it "converts time to UTC" do
        local_time = Time.new(2023, 12, 15, 15, 30, 45.123454, "-05:00")

        result = formatter.call(severity, local_time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["timestamp"]).to eq("2023-12-15T20:30:45.123454Z")
      end
    end

    context "with nil values" do
      it "handles nil severity" do
        result = formatter.call(nil, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to be_nil
      end

      it "handles nil progname" do
        result = formatter.call(severity, time, nil, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["progname"]).to be_nil
      end

      it "handles nil message" do
        allow(CMDx::Utils::Format).to receive(:to_log).with(nil).and_return(nil)

        result = formatter.call(severity, time, progname, nil)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to be_nil
      end
    end

    context "with special characters in strings" do
      it "properly escapes quotes in severity" do
        severity_with_quotes = 'INFO "quoted"'

        result = formatter.call(severity_with_quotes, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq('INFO "quoted"')
      end

      it "properly escapes newlines in progname" do
        progname_with_newline = "TestApp\nSecondLine"

        result = formatter.call(severity, time, progname_with_newline, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["progname"]).to eq("TestApp\nSecondLine")
      end

      it "handles unicode characters" do
        unicode_message = "Test message with émojis 🚀"

        allow(CMDx::Utils::Format).to receive(:to_log).with(unicode_message).and_return(unicode_message)

        result = formatter.call(severity, time, progname, unicode_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq("Test message with émojis 🚀")
      end
    end

    context "with CMDx objects as message" do
      let(:cmdx_hash) { { "state" => "complete", "status" => "success" } }

      it "uses Utils::Format.to_log for message processing" do
        allow(CMDx::Utils::Format).to receive(:to_log).with(message).and_return(cmdx_hash)

        expect(CMDx::Utils::Format).to receive(:to_log).with(message)

        result = formatter.call(severity, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq(cmdx_hash)
      end

      it "handles complex nested structures" do
        complex_hash = {
          "task" => "ProcessData",
          "context" => { "user_id" => 123, "session" => "abc123" },
          "metadata" => { "attempts" => 1, "duration" => 0.45 }
        }

        allow(CMDx::Utils::Format).to receive(:to_log).with(message).and_return(complex_hash)

        result = formatter.call(severity, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq(complex_hash)
      end
    end

    context "with numeric and boolean messages" do
      it "handles integer messages" do
        integer_message = 42
        allow(CMDx::Utils::Format).to receive(:to_log).with(integer_message).and_return(integer_message)

        result = formatter.call(severity, time, progname, integer_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq(42)
      end

      it "handles boolean messages" do
        boolean_message = true

        allow(CMDx::Utils::Format).to receive(:to_log).with(boolean_message).and_return(boolean_message)

        result = formatter.call(severity, time, progname, boolean_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to be(true)
      end

      it "handles float messages" do
        float_message = 3.14159

        allow(CMDx::Utils::Format).to receive(:to_log).with(float_message).and_return(float_message)

        result = formatter.call(severity, time, progname, float_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq(3.14159)
      end
    end

    context "with array messages" do
      it "handles array messages" do
        array_message = %w[item1 item2 item3]

        result = formatter.call(severity, time, progname, array_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq(%w[item1 item2 item3])
      end
    end

    context "with extreme time values" do
      it "handles very old timestamps" do
        old_time = Time.new(1970, 1, 1, 0, 0, 0.0)

        result = formatter.call(severity, old_time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["timestamp"]).to eq("1970-01-01T00:00:00.000000Z")
      end

      it "handles future timestamps" do
        future_time = Time.new(2099, 12, 31, 23, 59, 59.999999)

        result = formatter.call(severity, future_time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["timestamp"]).to eq("2099-12-31T23:59:59.999999Z")
      end
    end

    context "when Utils::Format.to_log raises an error" do
      it "allows the error to propagate" do
        allow(CMDx::Utils::Format).to receive(:to_log).and_raise(StandardError, "Format error")

        expect do
          formatter.call(severity, time, progname, message)
        end.to raise_error(StandardError, "Format error")
      end
    end

    context "with very long strings" do
      it "handles large messages without truncation" do
        large_message = "x" * 10_000

        allow(CMDx::Utils::Format).to receive(:to_log).with(large_message).and_return(large_message)

        result = formatter.call(severity, time, progname, large_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq(large_message)
        expect(parsed["message"].length).to eq(10_000)
      end
    end
  end
end

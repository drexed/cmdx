# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::KeyValue do
  subject(:formatter) { described_class.new }

  let(:severity) { "INFO" }
  let(:time) { Time.new(2023, 12, 15, 10, 30, 45.123454) }
  let(:progname) { "TestApp" }
  let(:message) { "Test message" }

  describe "#call" do
    context "with typical log parameters" do
      it "returns properly formatted key-value string with newline" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to eq(
          'severity="INFO" timestamp="2023-12-15T10:30:45.123454Z" progname="TestApp" ' \
          "pid=#{Process.pid} message=\"Test message\"\n"
        )
        expect(result).to end_with("\n")
      end

      it "includes current process PID" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to include("pid=#{Process.pid}")
      end

      it "formats timestamp in UTC ISO8601 with microseconds" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to include('timestamp="2023-12-15T10:30:45.123454Z"')
      end

      it "uses Utils::Format.to_log for message processing" do
        allow(CMDx::Utils::Format).to receive(:to_log).with(message).and_return("processed message")

        expect(CMDx::Utils::Format).to receive(:to_log).with(message)

        result = formatter.call(severity, time, progname, message)

        expect(result).to include('message="processed message"')
      end

      it "uses Utils::Format.to_str to format the hash" do
        expected_hash = {
          severity: severity,
          timestamp: time.utc.iso8601(6),
          progname: progname,
          pid: Process.pid,
          message: message
        }

        allow(CMDx::Utils::Format).to receive(:to_str).with(expected_hash).and_return(+"formatted output")

        expect(CMDx::Utils::Format).to receive(:to_str).with(expected_hash)

        result = formatter.call(severity, time, progname, message)

        expect(result).to eq("formatted output\n")
      end
    end

    context "with different severity levels" do
      %w[DEBUG INFO WARN ERROR FATAL].each do |level|
        it "handles #{level} severity" do
          result = formatter.call(level, time, progname, message)

          expect(result).to include("severity=\"#{level}\"")
        end
      end
    end

    context "with different time zones" do
      it "converts time to UTC" do
        local_time = Time.new(2023, 12, 15, 15, 30, 45.123454, "-05:00")

        result = formatter.call(severity, local_time, progname, message)

        expect(result).to include('timestamp="2023-12-15T20:30:45.123454Z"')
      end

      it "handles UTC time correctly" do
        utc_time = Time.new(2023, 12, 15, 10, 30, 45.123454, "+00:00")

        result = formatter.call(severity, utc_time, progname, message)

        expect(result).to include('timestamp="2023-12-15T10:30:45.123454Z"')
      end
    end

    context "with nil values" do
      it "handles nil severity" do
        result = formatter.call(nil, time, progname, message)

        expect(result).to include("severity=nil")
      end

      it "handles nil progname" do
        result = formatter.call(severity, time, nil, message)

        expect(result).to include("progname=nil")
      end

      it "handles nil message" do
        allow(CMDx::Utils::Format).to receive(:to_log).with(nil).and_return(nil)

        result = formatter.call(severity, time, progname, nil)

        expect(result).to include("message=nil")
      end
    end

    context "with special characters in strings" do
      it "properly escapes quotes in severity" do
        severity_with_quotes = 'INFO "quoted"'

        result = formatter.call(severity_with_quotes, time, progname, message)

        expect(result).to include('severity="INFO \"quoted\""')
      end

      it "properly escapes newlines in progname" do
        progname_with_newline = "TestApp\nSecondLine"

        result = formatter.call(severity, time, progname_with_newline, message)

        expect(result).to include("progname=\"TestApp\\nSecondLine\"")
      end

      it "handles unicode characters" do
        unicode_message = "Test message with émojis 🚀"

        allow(CMDx::Utils::Format).to receive(:to_log).with(unicode_message).and_return(unicode_message)

        result = formatter.call(severity, time, progname, unicode_message)

        expect(result).to include("message=\"Test message with émojis 🚀\"")
      end

      it "handles backslashes in strings" do
        message_with_backslash = "C:\\Windows\\Path"

        allow(CMDx::Utils::Format).to receive(:to_log).with(message_with_backslash).and_return(message_with_backslash)

        result = formatter.call(severity, time, progname, message_with_backslash)

        expect(result).to include("message=\"C:\\\\Windows\\\\Path\"")
      end
    end

    context "with CMDx objects as message" do
      let(:cmdx_hash) { { "state" => "complete", "status" => "success" } }

      it "processes CMDx objects through Utils::Format.to_log" do
        allow(CMDx::Utils::Format).to receive(:to_log).with(message).and_return(cmdx_hash)

        expect(CMDx::Utils::Format).to receive(:to_log).with(message)

        result = formatter.call(severity, time, progname, message)

        expect(result).to include('message={"state" => "complete", "status" => "success"}')
      end

      it "handles complex nested structures" do
        complex_hash = {
          "task" => "ProcessData",
          "context" => { "user_id" => 123, "session" => "abc123" },
          "metadata" => { "attempts" => 1, "duration" => 0.45 }
        }

        allow(CMDx::Utils::Format).to receive(:to_log).with(message).and_return(complex_hash)

        result = formatter.call(severity, time, progname, message)

        expect(result).to include("message=#{complex_hash.inspect}")
      end
    end

    context "with numeric and boolean messages" do
      it "handles integer messages" do
        integer_message = 42

        allow(CMDx::Utils::Format).to receive(:to_log).with(integer_message).and_return(integer_message)

        result = formatter.call(severity, time, progname, integer_message)

        expect(result).to include("message=42")
      end

      it "handles boolean messages" do
        boolean_message = true

        allow(CMDx::Utils::Format).to receive(:to_log).with(boolean_message).and_return(boolean_message)

        result = formatter.call(severity, time, progname, boolean_message)

        expect(result).to include("message=true")
      end

      it "handles float messages" do
        float_message = 3.14159

        allow(CMDx::Utils::Format).to receive(:to_log).with(float_message).and_return(float_message)

        result = formatter.call(severity, time, progname, float_message)

        expect(result).to include("message=3.14159")
      end

      it "handles false boolean message" do
        false_message = false

        allow(CMDx::Utils::Format).to receive(:to_log).with(false_message).and_return(false_message)

        result = formatter.call(severity, time, progname, false_message)

        expect(result).to include("message=false")
      end
    end

    context "with array messages" do
      it "handles array messages" do
        array_message = %w[item1 item2 item3]

        allow(CMDx::Utils::Format).to receive(:to_log).with(array_message).and_return(array_message)

        result = formatter.call(severity, time, progname, array_message)

        expect(result).to include('message=["item1", "item2", "item3"]')
      end

      it "handles empty array messages" do
        empty_array = []

        allow(CMDx::Utils::Format).to receive(:to_log).with(empty_array).and_return(empty_array)

        result = formatter.call(severity, time, progname, empty_array)

        expect(result).to include("message=[]")
      end
    end

    context "with extreme time values" do
      it "handles very old timestamps" do
        old_time = Time.new(1970, 1, 1, 0, 0, 0.0)

        result = formatter.call(severity, old_time, progname, message)

        expect(result).to include('timestamp="1970-01-01T00:00:00.000000Z"')
      end

      it "handles future timestamps" do
        future_time = Time.new(2099, 12, 31, 23, 59, 59.999999)

        result = formatter.call(severity, future_time, progname, message)

        expect(result).to include('timestamp="2099-12-31T23:59:59.999999Z"')
      end

      it "handles time with no microseconds" do
        time_no_microseconds = Time.new(2023, 1, 1, 12, 0, 0)

        result = formatter.call(severity, time_no_microseconds, progname, message)

        expect(result).to include('timestamp="2023-01-01T12:00:00.000000Z"')
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

    context "when Utils::Format.to_str raises an error" do
      it "allows the error to propagate" do
        allow(CMDx::Utils::Format).to receive(:to_str).and_raise(StandardError, "String format error")

        expect do
          formatter.call(severity, time, progname, message)
        end.to raise_error(StandardError, "String format error")
      end
    end

    context "with very long strings" do
      it "handles large messages without truncation" do
        large_message = "x" * 10_000

        allow(CMDx::Utils::Format).to receive(:to_log).with(large_message).and_return(large_message)

        result = formatter.call(severity, time, progname, large_message)

        expect(result).to include("message=\"#{'x' * 10_000}\"")
        expect(result.length).to be > 10_000
      end

      it "handles large progname" do
        large_progname = "LongApplicationName" * 100

        result = formatter.call(severity, time, large_progname, message)

        expect(result).to include("progname=\"#{large_progname}\"")
      end
    end

    context "with symbol values" do
      it "handles symbol severity" do
        symbol_severity = :warning

        result = formatter.call(symbol_severity, time, progname, message)

        expect(result).to include("severity=:warning")
      end

      it "handles symbol message" do
        symbol_message = :success

        allow(CMDx::Utils::Format).to receive(:to_log).with(symbol_message).and_return(symbol_message)

        result = formatter.call(severity, time, progname, symbol_message)

        expect(result).to include("message=:success")
      end
    end

    context "with hash message" do
      it "handles hash messages" do
        hash_message = { key: "value", count: 5 }

        allow(CMDx::Utils::Format).to receive(:to_log).with(hash_message).and_return(hash_message)

        result = formatter.call(severity, time, progname, hash_message)

        expect(result).to include("message={key: \"value\", count: 5}")
      end

      it "handles empty hash messages" do
        empty_hash = {}

        allow(CMDx::Utils::Format).to receive(:to_log).with(empty_hash).and_return(empty_hash)

        result = formatter.call(severity, time, progname, empty_hash)

        expect(result).to include("message={}")
      end
    end

    context "with empty string values" do
      it "handles empty string severity" do
        result = formatter.call("", time, progname, message)

        expect(result).to include('severity=""')
      end

      it "handles empty string progname" do
        result = formatter.call(severity, time, "", message)

        expect(result).to include('progname=""')
      end

      it "handles empty string message" do
        allow(CMDx::Utils::Format).to receive(:to_log).with("").and_return("")

        result = formatter.call(severity, time, progname, "")

        expect(result).to include('message=""')
      end
    end
  end
end

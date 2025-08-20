# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Line, type: :unit do
  subject(:formatter) { described_class.new }

  let(:severity) { "INFO" }
  let(:time) { Time.new(2023, 12, 15, 10, 30, 45.123454) }
  let(:progname) { "TestApp" }
  let(:message) { "Test message" }

  describe "#call" do
    context "with typical log parameters" do
      it "returns properly formatted line string with newline" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to eq("I, [2023-12-15T10:30:45.123454Z ##{Process.pid}] INFO -- TestApp: Test message\n")
        expect(result).to end_with("\n")
      end

      it "includes severity prefix as first character" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to start_with("I,")
      end

      it "includes current process PID" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to include("##{Process.pid}")
      end

      it "formats timestamp in UTC ISO8601 with microseconds" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to include("[2023-12-15T10:30:45.123454Z")
      end

      it "includes full severity name" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to include("] INFO --")
      end

      it "includes progname and message" do
        result = formatter.call(severity, time, progname, message)

        expect(result).to include("TestApp: Test message")
      end
    end

    context "with different severity levels" do
      %w[DEBUG INFO WARN ERROR FATAL].each do |level|
        it "handles #{level} severity with correct prefix" do
          result = formatter.call(level, time, progname, message)
          expected_prefix = level[0]

          expect(result).to start_with("#{expected_prefix},")
          expect(result).to include("] #{level} --")
        end
      end

      it "handles custom severity levels" do
        custom_severity = "TRACE"

        result = formatter.call(custom_severity, time, progname, message)

        expect(result).to start_with("T,")
        expect(result).to include("] TRACE --")
      end
    end

    context "with different time zones" do
      it "converts time to UTC" do
        local_time = Time.new(2023, 12, 15, 15, 30, 45.123454, "-05:00")

        result = formatter.call(severity, local_time, progname, message)

        expect(result).to include("[2023-12-15T20:30:45.123454Z")
      end

      it "handles UTC time correctly" do
        utc_time = Time.new(2023, 12, 15, 10, 30, 45.123454, "+00:00")

        result = formatter.call(severity, utc_time, progname, message)

        expect(result).to include("[2023-12-15T10:30:45.123454Z")
      end
    end

    context "with nil values" do
      it "handles nil severity" do
        expect do
          formatter.call(nil, time, progname, message)
        end.to raise_error(NoMethodError)
      end

      it "handles nil progname" do
        result = formatter.call(severity, time, nil, message)

        expect(result).to include("INFO -- : Test message")
      end

      it "handles nil message" do
        result = formatter.call(severity, time, progname, nil)

        expect(result).to include("TestApp: \n")
      end
    end

    context "with special characters in strings" do
      it "handles quotes in severity" do
        severity_with_quotes = 'INFO"quoted"'

        result = formatter.call(severity_with_quotes, time, progname, message)

        expect(result).to include('] INFO"quoted" --')
      end

      it "handles newlines in progname" do
        progname_with_newline = "TestApp\nSecondLine"

        result = formatter.call(severity, time, progname_with_newline, message)

        expect(result).to include("TestApp\nSecondLine: Test message")
      end

      it "handles unicode characters in message" do
        unicode_message = "Test message with émojis 🚀"

        result = formatter.call(severity, time, progname, unicode_message)

        expect(result).to include("TestApp: Test message with émojis 🚀")
      end

      it "handles backslashes in message" do
        message_with_backslash = "C:\\Windows\\Path"

        result = formatter.call(severity, time, progname, message_with_backslash)

        expect(result).to include("TestApp: C:\\Windows\\Path")
      end
    end

    context "with complex objects as message" do
      it "handles hash messages" do
        hash_message = { "state" => "complete", "status" => "success" }

        result = formatter.call(severity, time, progname, hash_message)

        if RubyVersion.min?(3.4)
          expect(result).to include('TestApp: {"state" => "complete", "status" => "success"}')
        else
          expect(result).to include('TestApp: {"state"=>"complete", "status"=>"success"}')
        end
      end

      it "handles array messages" do
        array_message = %w[item1 item2 item3]

        result = formatter.call(severity, time, progname, array_message)

        expect(result).to include('TestApp: ["item1", "item2", "item3"]')
      end

      it "handles numeric messages" do
        numeric_message = 42

        result = formatter.call(severity, time, progname, numeric_message)

        expect(result).to include("TestApp: 42")
      end

      it "handles boolean messages" do
        boolean_message = true

        result = formatter.call(severity, time, progname, boolean_message)

        expect(result).to include("TestApp: true")
      end
    end

    context "with extreme time values" do
      it "handles very old timestamps" do
        old_time = Time.new(1970, 1, 1, 0, 0, 0.0)

        result = formatter.call(severity, old_time, progname, message)

        expect(result).to include("[1970-01-01T00:00:00.000000Z")
      end

      it "handles future timestamps" do
        future_time = Time.new(2099, 12, 31, 23, 59, 59.999999)

        result = formatter.call(severity, future_time, progname, message)

        expect(result).to include("[2099-12-31T23:59:59.999999Z")
      end

      it "handles time with no microseconds" do
        time_no_microseconds = Time.new(2023, 1, 1, 12, 0, 0)

        result = formatter.call(severity, time_no_microseconds, progname, message)

        expect(result).to include("[2023-01-01T12:00:00.000000Z")
      end
    end

    context "with empty string values" do
      it "handles empty string severity" do
        result = formatter.call("", time, progname, message)

        expect(result).to start_with(", ")
      end

      it "handles empty string progname" do
        result = formatter.call(severity, time, "", message)

        expect(result).to include("INFO -- : Test message")
      end

      it "handles empty string message" do
        result = formatter.call(severity, time, progname, "")

        expect(result).to include("TestApp: \n")
      end
    end

    context "with very long strings" do
      it "handles large messages without truncation" do
        large_message = "x" * 10_000

        result = formatter.call(severity, time, progname, large_message)

        expect(result).to include("TestApp: #{'x' * 10_000}")
        expect(result.length).to be > 10_000
      end

      it "handles large progname" do
        large_progname = "LongApplicationName" * 100

        result = formatter.call(severity, time, large_progname, message)

        expect(result).to include("#{large_progname}: Test message")
      end

      it "handles large severity" do
        large_severity = "VERYLONGSEVERITYLEVEL" * 10

        result = formatter.call(large_severity, time, progname, message)

        expect(result).to start_with("V,")
        expect(result).to include("] #{large_severity} --")
      end
    end

    context "with symbol values" do
      it "handles symbol severity" do
        symbol_severity = :warning

        result = formatter.call(symbol_severity, time, progname, message)

        expect(result).to start_with("w,")
        expect(result).to include("] warning --")
      end

      it "handles symbol progname" do
        symbol_progname = :my_app

        result = formatter.call(severity, time, symbol_progname, message)

        expect(result).to include("my_app: Test message")
      end

      it "handles symbol message" do
        symbol_message = :success

        result = formatter.call(severity, time, progname, symbol_message)

        expect(result).to include("TestApp: success")
      end
    end
  end
end

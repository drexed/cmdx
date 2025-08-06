# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::JSON do
  subject(:formatter) { described_class.new }

  describe "#call" do
    let(:severity) { "INFO" }
    let(:time) { Time.new(2023, 12, 25, 10, 30, 45.123456) }
    let(:progname) { "MyApp" }
    let(:message) { "Test message" }

    it "returns JSON string with newline" do
      result = formatter.call(severity, time, progname, message)

      expect(result).to end_with("\n")
      expect { JSON.parse(result.chomp) }.not_to raise_error(JSON::ParserError)
    end

    it "includes all required fields in JSON output" do
      result = formatter.call(severity, time, progname, message)
      parsed = JSON.parse(result.chomp)

      expect(parsed).to include(
        "severity" => severity,
        "timestamp" => time.utc.iso8601(6),
        "progname" => progname,
        "pid" => Process.pid,
        "message" => message
      )
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

    context "with different time formats" do
      it "formats timestamp as UTC ISO8601 with microseconds" do
        local_time = Time.new(2023, 6, 15, 14, 30, 45.987654, "+05:00")

        result = formatter.call(severity, local_time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["timestamp"]).to eq(local_time.utc.iso8601(6))
        expect(parsed["timestamp"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\z/)
      end

      it "handles time with fractional seconds" do
        fractional_time = Time.at(1_703_505_045.123456)

        result = formatter.call(severity, fractional_time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["timestamp"]).to eq(fractional_time.utc.iso8601(6))
      end
    end

    context "with different progname values" do
      it "handles string progname" do
        result = formatter.call(severity, time, "TestApp", message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["progname"]).to eq("TestApp")
      end

      it "handles nil progname" do
        result = formatter.call(severity, time, nil, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["progname"]).to be_nil
      end

      it "handles empty string progname" do
        result = formatter.call(severity, time, "", message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["progname"]).to eq("")
      end
    end

    context "with different message types" do
      context "when message is a hash" do
        let(:hash_message) { { action: "user_login", user_id: 123, ip: "192.168.1.1" } }

        it "merges hash message with log metadata" do
          result = formatter.call(severity, time, progname, hash_message)
          parsed = JSON.parse(result.chomp)

          expect(parsed).to include(
            "severity" => severity,
            "timestamp" => time.utc.iso8601(6),
            "progname" => progname,
            "pid" => Process.pid,
            "action" => "user_login",
            "user_id" => 123,
            "ip" => "192.168.1.1"
          )
        end
      end

      context "when message responds to to_hash" do
        let(:convertible_message) do
          message = instance_double("Message")
          allow(message).to receive(:respond_to?).with(:to_hash).and_return(true)
          allow(message).to receive(:to_hash).and_return({ event: "test", data: "value" })
          message
        end

        it "converts message using to_hash and merges with metadata" do
          result = formatter.call(severity, time, progname, convertible_message)
          parsed = JSON.parse(result.chomp)

          expect(parsed).to include(
            "severity" => severity,
            "event" => "test",
            "data" => "value"
          )
        end
      end

      context "when message is a string" do
        it "wraps string in message key" do
          result = formatter.call(severity, time, progname, "Simple log message")
          parsed = JSON.parse(result.chomp)

          expect(parsed["message"]).to eq("Simple log message")
        end
      end

      context "when message is an array" do
        let(:array_message) { [1, 2, 3] }

        it "wraps array in message key" do
          result = formatter.call(severity, time, progname, array_message)
          parsed = JSON.parse(result.chomp)

          expect(parsed["message"]).to eq([1, 2, 3])
        end
      end

      context "when message is nil" do
        it "handles nil message" do
          result = formatter.call(severity, time, progname, nil)
          parsed = JSON.parse(result.chomp)

          expect(parsed).to include(
            "severity" => severity,
            "timestamp" => time.utc.iso8601(6),
            "progname" => progname,
            "pid" => Process.pid
          )
          expect(parsed).not_to have_key("message")
        end
      end

      context "when message contains special characters" do
        let(:special_message) { { text: "Line 1\nLine 2\t\"quoted\"" } }

        it "properly escapes special characters in JSON" do
          result = formatter.call(severity, time, progname, special_message)
          parsed = JSON.parse(result.chomp)

          expect(parsed["text"]).to eq("Line 1\nLine 2\t\"quoted\"")
        end
      end
    end

    context "when message hash conflicts with metadata keys" do
      let(:conflicting_message) do
        {
          severity: "CONFLICT",
          timestamp: "2020-01-01T00:00:00Z",
          progname: "ConflictApp",
          pid: 99_999,
          message: "This should be overridden"
        }
      end

      it "gives priority to metadata over message content" do
        result = formatter.call(severity, time, progname, conflicting_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["severity"]).to eq(severity)
        expect(parsed["timestamp"]).to eq(time.utc.iso8601(6))
        expect(parsed["progname"]).to eq(progname)
        expect(parsed["pid"]).to eq(Process.pid)
        expect(parsed["message"]).to eq("This should be overridden")
      end
    end

    context "with edge cases" do
      it "handles very long messages" do
        long_message = "x" * 10_000

        result = formatter.call(severity, time, progname, long_message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["message"]).to eq(long_message)
      end

      it "handles complex nested structures" do
        complex_message = {
          user: { id: 1, name: "John", roles: %w[admin user] },
          metadata: { ip: "127.0.0.1", timestamp: Time.now },
          tags: %w[auth login success]
        }

        result = formatter.call(severity, time, progname, complex_message)

        expect { JSON.parse(result.chomp) }.not_to raise_error
      end

      it "includes current process PID" do
        result = formatter.call(severity, time, progname, message)
        parsed = JSON.parse(result.chomp)

        expect(parsed["pid"]).to eq(Process.pid)
        expect(parsed["pid"]).to be_a(Integer)
      end
    end
  end
end

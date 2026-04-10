# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Logstash do
  let(:formatter) { described_class.new }
  let(:time) { Time.utc(2026, 4, 10, 12, 0, 0) }

  let(:result) do
    k = Class.new(CMDx::Task) { def work; end }
    k.execute
  end

  describe "#call" do
    it "formats a Result as Logstash JSON with trailing newline" do
      line = formatter.call("INFO", time, nil, result)
      expect(line).to end_with("\n")
      data = JSON.parse(line)
      expect(data["@version"]).to eq("1")
      expect(data["status"]).to eq(result.status)
    end

    it "formats a plain string with trailing newline" do
      line = formatter.call("WARN", time, nil, "x")
      expect(line).to end_with("\n")
      data = JSON.parse(line)
      expect(data["message"]).to eq("x")
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::KeyValue do
  let(:formatter) { described_class.new }
  let(:time) { Time.utc(2026, 4, 10, 12, 0, 0) }

  let(:result) do
    k = Class.new(CMDx::Task) { def work; end }
    k.execute
  end

  describe "#call" do
    it "formats a Result as key=value line with trailing newline" do
      line = formatter.call("INFO", time, nil, result)
      expect(line).to end_with("\n")
      expect(line).to include("severity=INFO")
      expect(line).to include("status=#{result.status}")
    end

    it "formats a plain string with trailing newline" do
      line = formatter.call("ERROR", time, nil, "oops")
      expect(line).to end_with("\n")
      expect(line).to include("message=oops")
    end
  end
end

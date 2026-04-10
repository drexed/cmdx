# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Raw do
  let(:formatter) { described_class.new }
  let(:time) { Time.utc(2026, 4, 10, 12, 0, 0) }

  let(:result) do
    k = Class.new(CMDx::Task) { def work; end }
    k.execute
  end

  describe "#call" do
    it "formats a Result using to_h with trailing newline" do
      line = formatter.call("INFO", time, nil, result)
      expect(line).to end_with("\n")
      expect(line).to include("success")
    end

    it "formats a plain value with trailing newline" do
      line = formatter.call("INFO", time, nil, "plain")
      expect(line).to eq("plain\n")
    end
  end
end

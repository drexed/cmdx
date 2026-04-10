# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Line do
  let(:formatter) { described_class.new }
  let(:time) { Time.utc(2026, 4, 10, 12, 0, 0) }

  let(:result) do
    k = Class.new(CMDx::Task) do
      def self.name
        "My::Task"
      end

      def work; end
    end
    k.execute
  end

  describe "#call" do
    it "formats a Result with trailing newline" do
      line = formatter.call("INFO", time, nil, result)
      expect(line).to end_with("\n")
      expect(line).to include("[SUCCESS]")
      expect(line).to include("My::Task")
      expect(line).to include(result.task_id)
    end

    it "formats a plain string with trailing newline" do
      line = formatter.call("INFO", time, nil, "hello")
      expect(line).to eq("hello\n")
    end
  end
end

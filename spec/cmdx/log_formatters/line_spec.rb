# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Line do
  subject(:formatter) { described_class.new }

  let(:time) { Time.utc(2024, 1, 2, 3, 4, 5) }

  it "emits a classic Logger-style line" do
    line = formatter.call("INFO", time, "cmdx", "hello")

    expect(line).to start_with("I, ")
    expect(line).to include("INFO -- cmdx: hello")
    expect(line).to include("##{Process.pid}")
    expect(line).to end_with("\n")
  end
end

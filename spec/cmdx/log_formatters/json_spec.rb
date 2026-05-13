# frozen_string_literal: true

require "json"

RSpec.describe CMDx::LogFormatters::JSON do
  subject(:formatter) { described_class.new }

  let(:time) { Time.utc(2024, 1, 2, 3, 4, 5) }

  it "emits a JSON line with core fields" do
    line = formatter.call("INFO", time, "cmdx", "hello")

    expect(line).to end_with("\n")

    hash = JSON.parse(line)
    expect(hash).to include(
      "severity" => "INFO",
      "progname" => "cmdx",
      "message" => "hello",
      "timestamp" => time.iso8601(6),
      "pid" => Process.pid
    )
  end

  it "serializes objects that respond to to_h via their hash form" do
    message = Struct.new(:name).new("alice")

    hash = JSON.parse(formatter.call("INFO", time, nil, message))
    expect(hash["message"]).to eq("name" => "alice")
  end
end

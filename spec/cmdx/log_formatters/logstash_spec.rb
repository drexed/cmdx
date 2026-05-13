# frozen_string_literal: true

require "json"

RSpec.describe CMDx::LogFormatters::Logstash do
  subject(:formatter) { described_class.new }

  let(:time) { Time.utc(2024, 1, 2, 3, 4, 5) }

  it "emits a Logstash-shaped JSON line" do
    line = formatter.call("INFO", time, "cmdx", "hello")

    expect(line).to end_with("\n")

    hash = JSON.parse(line)
    expect(hash).to include(
      "severity" => "INFO",
      "progname" => "cmdx",
      "message" => "hello",
      "@version" => "1",
      "@timestamp" => time.iso8601(6),
      "pid" => Process.pid
    )
  end

  it "serializes to_h-capable messages" do
    message = Struct.new(:event).new("ping")
    hash = JSON.parse(formatter.call("INFO", time, nil, message))
    expect(hash["message"]).to eq("event" => "ping")
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::KeyValue do
  subject(:formatter) { described_class.new }

  let(:time) { Time.utc(2024, 1, 2, 3, 4, 5) }

  it "emits key=value pairs" do
    line = formatter.call("INFO", time, "cmdx", "hello")

    expect(line).to end_with("\n")
    expect(line).to include('severity="INFO"', 'progname="cmdx"', 'message="hello"')
    expect(line).to include("pid=#{Process.pid}")
  end

  it "uses to_h for message objects" do
    message = Struct.new(:name).new("alice")
    line    = formatter.call("INFO", time, nil, message)

    expect(line).to include("message=#{message.to_h.inspect}")
  end
end

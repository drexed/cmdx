# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LogFormatters::Raw do
  subject(:formatter) { described_class.new }

  it "emits just the message with a newline" do
    expect(formatter.call("INFO", Time.now, "cmdx", "hello")).to eq("hello\n")
  end

  it "calls #to_s implicitly via interpolation" do
    obj = Object.new
    def obj.to_s = "custom"

    expect(formatter.call("INFO", Time.now, nil, obj)).to eq("custom\n")
  end
end

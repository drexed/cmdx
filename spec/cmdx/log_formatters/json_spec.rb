# frozen_string_literal: true

RSpec.describe CMDx::LogFormatters::Json do
  subject(:formatter) { described_class.new }

  it "outputs valid JSON" do
    data = { state: "complete", status: "success", metadata: {} }
    output = formatter.call(data)
    parsed = JSON.parse(output)
    expect(parsed["state"]).to eq("complete")
    expect(parsed["status"]).to eq("success")
  end

  it "serializes exceptions" do
    data = { cause: RuntimeError.new("boom") }
    output = formatter.call(data)
    parsed = JSON.parse(output)
    expect(parsed["cause"]).to include("boom")
    expect(parsed["cause"]).to include("RuntimeError")
  end
end

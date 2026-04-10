# frozen_string_literal: true

RSpec.describe CMDx::LogFormatters::Logstash do
  subject(:formatter) { described_class.new }

  it "outputs logstash-compatible JSON" do
    data = { state: "complete" }
    output = formatter.call(data)
    parsed = JSON.parse(output)
    expect(parsed).to have_key("@version")
    expect(parsed).to have_key("@timestamp")
    expect(parsed["progname"]).to eq("cmdx")
    expect(parsed["message"]["state"]).to eq("complete")
  end
end

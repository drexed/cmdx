# frozen_string_literal: true

RSpec.describe CMDx::LogFormatters::KeyValue do
  subject(:formatter) { described_class.new }

  it "formats as key=value pairs" do
    data = { state: "complete", count: 5 }
    output = formatter.call(data)
    expect(output).to include('state="complete"')
    expect(output).to include("count=5")
  end
end

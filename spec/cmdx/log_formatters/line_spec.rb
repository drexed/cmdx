# frozen_string_literal: true

RSpec.describe CMDx::LogFormatters::Line do
  subject(:formatter) { described_class.new }

  it "formats data as key-value pairs" do
    data = { state: "complete", status: "success" }
    output = formatter.call(data)
    expect(output).to include("state:")
    expect(output).to include("status:")
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::LogFormatters::Raw do
  subject(:formatter) { described_class.new }

  it "outputs inspect representation" do
    data = { x: 1 }
    expect(formatter.call(data)).to eq(data.inspect)
  end
end

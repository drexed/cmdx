# frozen_string_literal: true

RSpec.describe CMDx::Retriers::Linear do
  describe ".call" do
    it "scales arithmetically with the attempt" do
      expect(described_class.call(0, 1.0)).to eq(1.0)
      expect(described_class.call(3, 0.25)).to eq(1.0)
    end
  end
end

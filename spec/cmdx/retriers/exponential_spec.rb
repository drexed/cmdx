# frozen_string_literal: true

RSpec.describe CMDx::Retriers::Exponential do
  describe ".call" do
    it "doubles the base delay each attempt" do
      expect(described_class.call(0, 0.5)).to eq(0.5)
      expect(described_class.call(3, 0.5)).to eq(4.0)
    end

    it "caps the exponent at MAX_SHIFT" do
      huge = described_class.call(1_000, 1.0)
      capped = described_class.call(CMDx::Retriers::Exponential::MAX_SHIFT, 1.0)

      expect(huge).to eq(capped)
    end
  end
end

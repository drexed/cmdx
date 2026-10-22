# frozen_string_literal: true

RSpec.describe CMDx::Retriers::HalfRandom do
  describe ".call" do
    it "samples within [delay/2, delay]" do
      allow(described_class).to receive(:rand).and_return(0.0, 1.0)

      expect(described_class.call(0, 2.0)).to eq(1.0)
      expect(described_class.call(0, 2.0)).to eq(2.0)
    end
  end
end

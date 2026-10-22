# frozen_string_literal: true

RSpec.describe CMDx::Retriers::FullRandom do
  describe ".call" do
    it "samples within [0, delay]" do
      allow(described_class).to receive(:rand).and_return(0.25)

      expect(described_class.call(0, 2.0)).to eq(0.5)
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Retriers::BoundedRandom do
  describe ".call" do
    it "samples within [delay, 2*delay]" do
      allow(described_class).to receive(:rand).and_return(0.5)

      expect(described_class.call(0, 2.0)).to eq(3.0)
    end
  end
end

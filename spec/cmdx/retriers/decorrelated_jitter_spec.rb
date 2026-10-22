# frozen_string_literal: true

RSpec.describe CMDx::Retriers::DecorrelatedJitter do
  describe ".call" do
    it "samples in [delay, 3*delay] when prev_delay is nil" do
      allow(described_class).to receive(:rand).and_return(0.0, 1.0)

      expect(described_class.call(0, 1.0)).to eq(1.0)
      expect(described_class.call(0, 1.0)).to eq(3.0)
    end

    it "widens the upper bound from prev_delay" do
      allow(described_class).to receive(:rand).and_return(1.0)

      expect(described_class.call(0, 1.0, 4.0)).to eq(12.0)
    end
  end
end

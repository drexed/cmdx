# frozen_string_literal: true

RSpec.describe CMDx::StoreKey do
  describe ".compose" do
    it "joins coerced segments" do
      expect(described_class.compose("cmdx:idem", "ChargeCustomer", "pay_123")).to eq("cmdx:idem:ChargeCustomer:pay_123")
    end

    it "raises when a segment is empty" do
      expect { described_class.compose("cmdx:idem", "") }.to raise_error(ArgumentError, /store key must be non-empty/)
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Identifier do
  describe ".generate" do
    it "returns a UUID string" do
      id = described_class.generate
      expect(id).to be_a(String)
      expect(id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it "generates unique values" do
      ids = Array.new(100) { described_class.generate }
      expect(ids.uniq.size).to eq(100)
    end
  end
end

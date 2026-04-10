# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Identifier do
  describe ".generate" do
    it "returns a UUID-shaped string" do
      id = described_class.generate
      expect(id).to be_a(String)
      expect(id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end

    it "returns a different value on each call" do
      ids = Array.new(50) { described_class.generate }
      expect(ids.uniq.size).to eq(50)
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Coercions::String do
  describe ".call" do
    it "converts numbers" do
      expect(described_class.call(42)).to eq("42")
    end

    it "converts symbols" do
      expect(described_class.call(:hello)).to eq("hello")
    end

    it "returns strings unchanged" do
      expect(described_class.call("hi")).to eq("hi")
    end
  end
end

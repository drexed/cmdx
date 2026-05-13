# frozen_string_literal: true

RSpec.describe CMDx::Coercions::Float do
  describe ".call" do
    it "converts numeric strings" do
      expect(described_class.call("3.14")).to eq(3.14)
    end

    it "converts integers" do
      expect(described_class.call(42)).to eq(42.0)
    end

    it "returns a Failure for unparseable input" do
      expect(described_class.call("nope")).to be_a(CMDx::Coercions::Failure)
    end

    it "returns a Failure for nil" do
      expect(described_class.call(nil)).to be_a(CMDx::Coercions::Failure)
    end
  end
end

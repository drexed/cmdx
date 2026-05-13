# frozen_string_literal: true

RSpec.describe CMDx::Validators::Presence do
  describe ".call" do
    it "passes for non-blank strings" do
      expect(described_class.call("x")).to be_nil
    end

    it "passes for non-empty arrays" do
      expect(described_class.call([1])).to be_nil
    end

    it "passes for truthy scalars" do
      expect(described_class.call(42)).to be_nil
    end

    it "fails for nil" do
      expect(described_class.call(nil)).to be_a(CMDx::Validators::Failure)
    end

    it "fails for blank strings" do
      expect(described_class.call("   ")).to be_a(CMDx::Validators::Failure)
    end

    it "fails for empty arrays" do
      expect(described_class.call([])).to be_a(CMDx::Validators::Failure)
    end

    it "uses :message when supplied" do
      f = described_class.call(nil, message: "required")
      expect(f.message).to eq("required")
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Absence do
  describe ".call" do
    it "passes for nil" do
      expect(described_class.call(nil)).to be_nil
    end

    it "passes for a blank string" do
      expect(described_class.call("   ")).to be_nil
    end

    it "passes for an empty array" do
      expect(described_class.call([])).to be_nil
    end

    it "fails for non-blank strings" do
      expect(described_class.call("x")).to be_a(CMDx::Validators::Failure)
    end

    it "fails for non-empty arrays" do
      expect(described_class.call([1])).to be_a(CMDx::Validators::Failure)
    end

    it "fails for scalars" do
      expect(described_class.call(1)).to be_a(CMDx::Validators::Failure)
    end

    it "uses :message when supplied" do
      f = described_class.call("hi", message: "must be blank")
      expect(f.message).to eq("must be blank")
    end
  end
end

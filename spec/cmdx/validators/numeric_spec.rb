# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Numeric do
  describe ".call" do
    it "validates :is" do
      expect(described_class.call(3, is: 3)).to be_nil
      expect(described_class.call(2, is: 3)).to eq(CMDx::Locale.t("cmdx.validators.numeric.is", is: 3))
    end

    it "validates :is_not" do
      expect(described_class.call(2, is_not: 3)).to be_nil
      expect(described_class.call(3, is_not: 3)).to eq(
        CMDx::Locale.t("cmdx.validators.numeric.is_not", is_not: 3)
      )
    end

    it "validates :min" do
      expect(described_class.call(3, min: 2)).to be_nil
      expect(described_class.call(1, min: 2)).to eq(CMDx::Locale.t("cmdx.validators.numeric.min", min: 2))
    end

    it "validates :max" do
      expect(described_class.call(2, max: 3)).to be_nil
      expect(described_class.call(4, max: 3)).to eq(CMDx::Locale.t("cmdx.validators.numeric.max", max: 3))
    end

    it "validates :within" do
      range = 1..10
      expect(described_class.call(5, within: range)).to be_nil
      expect(described_class.call(11, within: range)).to eq(
        CMDx::Locale.t("cmdx.validators.numeric.within", min: range.min, max: range.max)
      )
    end

    it "returns nil for nil value" do
      expect(described_class.call(nil, is: 1)).to be_nil
    end

    it "returns nil for non-numeric values (no checks applied)" do
      expect(described_class.call("3", min: 1)).to be_nil
    end
  end
end

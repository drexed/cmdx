# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Length do
  describe ".call" do
    it "validates :is" do
      expect(described_class.call("abc", is: 3)).to be_nil
      expect(described_class.call("ab", is: 3)).to eq(CMDx::Locale.t("cmdx.validators.length.is", is: 3))
    end

    it "validates :is_not" do
      expect(described_class.call("ab", is_not: 3)).to be_nil
      expect(described_class.call("abc", is_not: 3)).to eq(
        CMDx::Locale.t("cmdx.validators.length.is_not", is_not: 3)
      )
    end

    it "validates :min" do
      expect(described_class.call("abc", min: 2)).to be_nil
      expect(described_class.call("a", min: 2)).to eq(CMDx::Locale.t("cmdx.validators.length.min", min: 2))
    end

    it "validates :max" do
      expect(described_class.call("ab", max: 3)).to be_nil
      expect(described_class.call("abcd", max: 3)).to eq(CMDx::Locale.t("cmdx.validators.length.max", max: 3))
    end

    it "validates :within" do
      range = 2..4
      expect(described_class.call("abc", within: range)).to be_nil
      expect(described_class.call("a", within: range)).to eq(
        CMDx::Locale.t("cmdx.validators.length.within", min: range.min, max: range.max)
      )
    end

    it "returns nil for nil value" do
      expect(described_class.call(nil, is: 1)).to be_nil
    end
  end
end

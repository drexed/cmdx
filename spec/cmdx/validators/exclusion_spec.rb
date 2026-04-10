# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Exclusion do
  describe ".call" do
    it "rejects values in :of" do
      forbidden = [1, 2, 3]
      expect(described_class.call(0, of: forbidden)).to be_nil
      expect(described_class.call(2, of: forbidden)).to eq(
        CMDx::Locale.t("cmdx.validators.exclusion.of", values: forbidden.join(", "))
      )
    end

    it "rejects values inside :within" do
      range = 1..10
      expect(described_class.call(11, within: range)).to be_nil
      expect(described_class.call(5, within: range)).to eq(
        CMDx::Locale.t("cmdx.validators.exclusion.within", min: range.min, max: range.max)
      )
    end
  end
end

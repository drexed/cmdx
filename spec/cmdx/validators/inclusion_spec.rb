# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Inclusion do
  describe ".call" do
    it "validates membership with :of" do
      allowed = [1, 2, 3]
      expect(described_class.call(2, of: allowed)).to be_nil
      expect(described_class.call(9, of: allowed)).to eq(
        CMDx::Locale.t("cmdx.validators.inclusion.of", values: allowed.join(", "))
      )
    end

    it "validates range with :within" do
      range = 1..10
      expect(described_class.call(5, within: range)).to be_nil
      expect(described_class.call(11, within: range)).to eq(
        CMDx::Locale.t("cmdx.validators.inclusion.within", min: range.min, max: range.max)
      )
    end
  end
end

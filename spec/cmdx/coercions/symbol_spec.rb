# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Symbol do
  describe ".call" do
    it "coerces from String" do
      expect(described_class.call("bar")).to eq(:bar)
    end
  end
end

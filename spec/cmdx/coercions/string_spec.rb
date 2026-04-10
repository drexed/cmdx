# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::String do
  describe ".call" do
    it "coerces from Integer" do
      expect(described_class.call(100)).to eq("100")
    end

    it "coerces from Symbol" do
      expect(described_class.call(:foo)).to eq("foo")
    end
  end
end

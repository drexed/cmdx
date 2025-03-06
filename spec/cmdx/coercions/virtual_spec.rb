# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Virtual do
  subject(:coercion) { described_class.call(1) }

  describe ".call" do
    it "returns the object" do
      expect(coercion).to eq(1)
    end
  end
end

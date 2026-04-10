# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Boolean do
  describe ".call" do
    it "treats configured truthy values as true" do
      %w[1 true yes on t y].each do |s|
        expect(described_class.call(s)).to be(true)
      end
      expect(described_class.call(true)).to be(true)
      expect(described_class.call(1)).to be(true)
    end

    it "treats configured falsy values as false" do
      %w[0 false no off f n].each do |s|
        expect(described_class.call(s)).to be(false)
      end
      expect(described_class.call(false)).to be(false)
      expect(described_class.call(0)).to be(false)
      expect(described_class.call(nil)).to be(false)
    end

    it "uses !!value for other objects" do
      expect(described_class.call(Object.new)).to be(true)
    end
  end
end

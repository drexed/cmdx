# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Errors do
  subject(:errors) { described_class.new }

  describe "#add" do
    it "stores messages per attribute using a Set (no duplicate messages)" do
      errors.add(:email, "is invalid")
      errors.add(:email, "is invalid")
      errors.add(:email, "can't be blank")
      expect(errors.messages[:email].to_a).to contain_exactly("is invalid", "can't be blank")
    end

    it "ignores empty messages" do
      errors.add(:name, "")
      expect(errors.messages).to be_empty
    end
  end

  describe "#for?" do
    it "is true when the attribute has messages" do
      errors.add(:foo, "nope")
      expect(errors.for?(:foo)).to be true
    end

    it "is false when the attribute has no messages" do
      expect(errors.for?(:foo)).to be false
    end
  end

  describe "#empty?, #any?, #size" do
    it "reports emptiness and attribute count" do
      expect(errors.empty?).to be true
      expect(errors.any?).to be false
      expect(errors.size).to eq(0)

      errors.add(:a, "one")
      errors.add(:b, "two")
      errors.add(:b, "three")

      expect(errors.empty?).to be false
      expect(errors.any?).to be true
      expect(errors.size).to eq(2)
    end
  end

  describe "#clear" do
    it "removes all messages" do
      errors.add(:x, "y")
      errors.clear
      expect(errors.messages).to be_empty
      expect(errors.empty?).to be true
    end
  end

  describe "#full_messages" do
    it "prepends the attribute name to each message" do
      errors.add(:email, "is invalid")
      expect(errors.full_messages).to eq({ email: ["email is invalid"] })
    end
  end

  describe "#to_h" do
    it "returns arrays of messages without attribute prefixes" do
      errors.add(:name, "too short")
      expect(errors.to_h).to eq({ name: ["too short"] })
    end
  end

  describe "#to_s" do
    it "joins full messages with period-space" do
      errors.add(:a, "bad")
      errors.add(:b, "worse")
      str = errors.to_s
      expect(str).to include("a bad")
      expect(str).to include("b worse")
      expect(str).to include(". ")
    end
  end
end

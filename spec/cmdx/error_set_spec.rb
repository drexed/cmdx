# frozen_string_literal: true

RSpec.describe CMDx::ErrorSet do
  subject(:errors) { described_class.new }

  it "starts empty" do
    expect(errors).to be_empty
    expect(errors).not_to be_any
    expect(errors.size).to eq(0)
  end

  describe "#add" do
    it "adds errors for an attribute" do
      errors.add(:email, "is required")
      errors.add(:email, "is invalid")
      errors.add(:name, "is too short")

      expect(errors.size).to eq(2)
      expect(errors).to be_any
      expect(errors.for?(:email)).to be(true)
      expect(errors.for?(:name)).to be(true)
      expect(errors.for?(:phone)).to be(false)
    end
  end

  describe "#to_h" do
    it "returns a hash of errors" do
      errors.add(:email, "is required")
      expect(errors.to_h).to eq(email: ["is required"])
    end
  end

  describe "#full_messages" do
    it "prefixes each message with the attribute name" do
      errors.add(:email, "is required")
      expect(errors.full_messages).to eq(email: ["email is required"])
    end
  end

  describe "#to_s" do
    it "joins all full messages" do
      errors.add(:email, "is required")
      errors.add(:name, "is too short")
      expect(errors.to_s).to eq("email is required. name is too short")
    end
  end

  describe "#clear" do
    it "removes all errors" do
      errors.add(:x, "bad")
      errors.clear
      expect(errors).to be_empty
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Errors do
  subject(:errors) { described_class.new }

  describe "#add" do
    it "adds an ErrorDetail and returns it" do
      detail = errors.add(:email, "is invalid", :format)
      expect(detail).to be_a(CMDx::ErrorDetail)
      expect(detail.attribute).to eq(:email)
      expect(detail.message).to eq("is invalid")
      expect(detail.code).to eq(:format)
    end
  end

  describe "#any? / #empty?" do
    it "is empty when no errors" do
      expect(errors).to be_empty
      expect(errors.any?).to be false
    end

    it "is not empty after adding" do
      errors.add(:name, "required")
      expect(errors.any?).to be true
      expect(errors).not_to be_empty
    end
  end

  describe "#[]" do
    it "returns details for a given attribute" do
      errors.add(:name, "too short")
      errors.add(:name, "required")
      expect(errors[:name].size).to eq(2)
      expect(errors[:name].map(&:message)).to eq(["too short", "required"])
    end
  end

  describe "#full_messages" do
    it "returns formatted messages" do
      errors.add(:name, "is required")
      errors.add(:email, "is invalid")
      expect(errors.full_messages).to contain_exactly("name is required", "email is invalid")
    end
  end

  describe "#to_h" do
    it "returns a hash of attribute => messages" do
      errors.add(:name, "too short")
      errors.add(:name, "required")
      expect(errors.to_h).to eq(name: ["too short", "required"])
    end
  end

  describe "#clear" do
    it "removes all errors" do
      errors.add(:a, "err")
      errors.clear
      expect(errors).to be_empty
    end
  end
end

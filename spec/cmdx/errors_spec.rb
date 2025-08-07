# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Errors do
  subject(:errors) { described_class.new }

  describe "#initialize" do
    it "initializes with empty messages hash" do
      expect(errors.messages).to eq({})
    end

    it "is empty by default" do
      expect(errors).to be_empty
    end
  end

  describe "#add" do
    context "when adding a valid message" do
      it "adds a message for an attribute" do
        errors.add(:name, "is required")

        expect(errors.messages[:name]).to include("is required")
      end

      it "creates a Set for the attribute if it doesn't exist" do
        errors.add(:email, "is invalid")

        expect(errors.messages[:email]).to be_a(Set)
      end

      it "adds multiple messages for the same attribute" do
        errors.add(:password, "is too short")
        errors.add(:password, "must contain numbers")

        expect(errors.messages[:password]).to include("is too short", "must contain numbers")
        expect(errors.messages[:password].size).to eq(2)
      end

      it "does not duplicate the same message for an attribute" do
        errors.add(:username, "is taken")
        errors.add(:username, "is taken")

        expect(errors.messages[:username].size).to eq(1)
        expect(errors.messages[:username]).to include("is taken")
      end

      it "handles string attributes" do
        errors.add("category", "is invalid")

        expect(errors.messages["category"]).to include("is invalid")
      end

      it "handles symbol attributes" do
        errors.add(:status, "is not allowed")

        expect(errors.messages[:status]).to include("is not allowed")
      end
    end

    context "when adding an empty message" do
      it "does not add empty string messages" do
        errors.add(:name, "")

        expect(errors.messages).to eq({})
        expect(errors).to be_empty
      end

      it "raises an error when trying to add nil messages" do
        expect { errors.add(:name, nil) }.to raise_error(NoMethodError, /undefined method.*empty.*for nil/)
      end
    end
  end

  describe "#for?" do
    context "when attribute has errors" do
      before do
        errors.add(:email, "is required")
      end

      it "returns true for attributes with errors" do
        expect(errors.for?(:email)).to be(true)
      end
    end

    context "when attribute has no errors" do
      it "returns false for attributes without errors" do
        expect(errors.for?(:name)).to be(false)
      end

      it "returns false for non-existent attributes" do
        expect(errors.for?(:nonexistent)).to be(false)
      end
    end

    context "when attribute exists but has empty errors" do
      before do
        errors.messages[:status] = Set.new
      end

      it "returns false for attributes with empty error sets" do
        expect(errors.for?(:status)).to be(false)
      end
    end
  end

  describe "#empty?" do
    context "when no errors have been added" do
      it "returns true" do
        expect(errors).to be_empty
      end
    end

    context "when errors have been added" do
      before do
        errors.add(:name, "is required")
      end

      it "returns false" do
        expect(errors).not_to be_empty
      end
    end

    context "when only empty messages were attempted to be added" do
      before do
        errors.add(:name, "")
      end

      it "returns true" do
        expect(errors).to be_empty
      end
    end
  end

  describe "#to_h" do
    context "when there are no errors" do
      it "returns an empty hash" do
        expect(errors.to_h).to eq({})
      end
    end

    context "when there are errors" do
      before do
        errors.add(:name, "is required")
        errors.add(:name, "is too short")
        errors.add(:email, "is invalid")
      end

      it "returns a hash with arrays as values" do
        result = errors.to_h

        expect(result[:name]).to be_a(Array)
        expect(result[:email]).to be_a(Array)
      end

      it "converts Sets to Arrays for each attribute" do
        result = errors.to_h

        expect(result[:name]).to contain_exactly("is required", "is too short")
        expect(result[:email]).to contain_exactly("is invalid")
      end

      it "preserves all error messages" do
        result = errors.to_h

        expect(result[:name].size).to eq(2)
        expect(result[:email].size).to eq(1)
      end
    end
  end

  describe "#to_s" do
    context "when there are no errors" do
      it "returns an empty string" do
        expect(errors.to_s).to eq("")
      end
    end

    context "when there is one error for one attribute" do
      before do
        errors.add(:name, "is required")
      end

      it "returns a formatted string" do
        expect(errors.to_s).to eq("name is required")
      end
    end

    context "when there are multiple errors for one attribute" do
      before do
        errors.add(:password, "is too short")
        errors.add(:password, "must contain numbers")
      end

      it "returns all errors for the attribute separated by periods" do
        result = errors.to_s

        expect(result).to include("password is too short")
        expect(result).to include("password must contain numbers")
        expect(result.split(". ").length).to eq(2)
      end
    end

    context "when there are errors for multiple attributes" do
      before do
        errors.add(:name, "is required")
        errors.add(:email, "is invalid")
        errors.add(:password, "is too short")
      end

      it "returns all errors separated by periods" do
        result = errors.to_s

        expect(result).to include("name is required")
        expect(result).to include("email is invalid")
        expect(result).to include("password is too short")
        expect(result.split(". ").length).to eq(3)
      end
    end

    context "when there are mixed attribute types" do
      before do
        errors.add(:symbol_attr, "symbol error")
        errors.add("string_attr", "string error")
      end

      it "handles both string and symbol attributes" do
        result = errors.to_s

        expect(result).to include("symbol_attr symbol error")
        expect(result).to include("string_attr string error")
      end
    end
  end
end

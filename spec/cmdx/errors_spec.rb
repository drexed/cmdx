# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Errors do
  subject(:errors) { described_class.new }

  describe "#initialize" do
    it "creates empty error collection" do
      expect(errors).to be_empty
      expect(errors.errors).to eq({})
    end
  end

  describe "#add" do
    it "adds error message to attribute" do
      errors.add(:name, "is required")

      expect(errors[:name]).to eq(["is required"])
    end

    it "appends multiple messages to same attribute" do
      errors.add(:email, "is required")
      errors.add(:email, "must be valid")

      expect(errors[:email]).to eq(["is required", "must be valid"])
    end

    it "removes duplicate messages automatically" do
      errors.add(:age, "must be positive")
      errors.add(:age, "must be positive")

      expect(errors[:age]).to eq(["must be positive"])
    end

    it "works with string keys" do
      errors.add("username", "is taken")

      expect(errors["username"]).to eq(["is taken"])
    end
  end

  describe "#[]=" do
    it "is an alias for add" do
      errors[:name] = "is required"

      expect(errors[:name]).to eq(["is required"])
    end
  end

  describe "#added?" do
    before do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")
    end

    it "returns true when specific error exists" do
      expect(errors.added?(:name, "is required")).to be true
    end

    it "returns false when specific error doesn't exist" do
      expect(errors.added?(:name, "is invalid")).to be false
    end

    it "returns false when attribute has no errors" do
      expect(errors.added?(:missing, "any error")).to be false
    end
  end

  describe "#of_kind?" do
    it "is an alias for added?" do
      errors.add(:email, "is invalid")

      expect(errors.of_kind?(:email, "is invalid")).to be true
    end
  end

  describe "#each" do
    before do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")
      errors.add(:email, "is invalid")
    end

    it "yields attribute and message pairs" do
      yielded = []
      errors.each { |attr, msg| yielded << [attr, msg] } # rubocop:disable Style/MapIntoArray

      expect(yielded).to contain_exactly(
        [:name, "is required"],
        [:name, "is too short"],
        [:email, "is invalid"]
      )
    end

    it "doesn't yield anything for empty errors" do
      empty_errors = described_class.new
      yielded = []
      empty_errors.each { |attr, msg| yielded << [attr, msg] } # rubocop:disable Style/MapIntoArray

      expect(yielded).to be_empty
    end
  end

  describe "#map" do
    before do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")
      errors.add(:email, "is invalid")
    end

    it "returns array of transformed values" do
      result = errors.map { |attr, msg| [attr, msg] }

      expect(result).to contain_exactly(
        [:name, "is required"],
        [:name, "is too short"],
        [:email, "is invalid"]
      )
    end

    it "transforms error messages to custom format" do
      result = errors.map { |attr, msg| "#{attr.upcase}: #{msg}" }

      expect(result).to contain_exactly(
        "NAME: is required",
        "NAME: is too short",
        "EMAIL: is invalid"
      )
    end

    it "extracts only attribute names" do
      result = errors.map { |attr, _msg| attr }

      expect(result).to contain_exactly(:name, :name, :email)
    end

    it "extracts only error messages" do
      result = errors.map { |_attr, msg| msg }

      expect(result).to contain_exactly(
        "is required",
        "is too short",
        "is invalid"
      )
    end

    it "returns empty array for empty errors" do
      empty_errors = described_class.new
      result = empty_errors.map { |attr, msg| [attr, msg] }

      expect(result).to be_empty
    end

    it "preserves order within attributes" do
      errors.clear
      errors.add(:status, "first error")
      errors.add(:status, "second error")
      errors.add(:status, "third error")

      result = errors.map { |attr, msg| "#{attr}: #{msg}" }

      expect(result).to eq([
                             "status: first error",
                             "status: second error",
                             "status: third error"
                           ])
    end

    it "handles complex transformations" do
      result = errors.map do |attr, msg|
        {
          field: attr.to_s.upcase,
          error: msg,
          length: msg.length
        }
      end

      expect(result).to contain_exactly(
        { field: "NAME", error: "is required", length: 11 },
        { field: "NAME", error: "is too short", length: 12 },
        { field: "EMAIL", error: "is invalid", length: 10 }
      )
    end
  end

  describe "#full_message" do
    it "formats attribute and error message" do
      result = errors.full_message(:name, "is required")

      expect(result).to eq("name is required")
    end

    it "works with string keys" do
      result = errors.full_message("email", "must be valid")

      expect(result).to eq("email must be valid")
    end
  end

  describe "#full_messages" do
    context "with multiple errors" do
      before do
        errors.add(:name, "is required")
        errors.add(:name, "is too short")
        errors.add(:email, "is invalid")
      end

      it "returns array of formatted error messages" do
        result = errors.full_messages

        expect(result).to contain_exactly(
          "name is required",
          "name is too short",
          "email is invalid"
        )
      end
    end

    context "with no errors" do
      it "returns empty array" do
        expect(errors.full_messages).to eq([])
      end
    end
  end

  describe "#to_a" do
    it "is an alias for full_messages" do
      errors.add(:status, "is pending")

      expect(errors.to_a).to eq(["status is pending"])
    end
  end

  describe "#full_messages_for" do
    before do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")
      errors.add(:email, "is invalid")
    end

    it "returns formatted messages for specific attribute" do
      result = errors.full_messages_for(:name)

      expect(result).to eq(["name is required", "name is too short"])
    end

    it "returns empty array for attribute without errors" do
      result = errors.full_messages_for(:missing)

      expect(result).to eq([])
    end
  end

  describe "#invalid?" do
    it "returns false when no errors present" do
      expect(errors.invalid?).to be false
    end

    it "returns true when errors are present" do
      errors.add(:name, "is required")

      expect(errors.invalid?).to be true
    end
  end

  describe "#merge!" do
    let(:other_errors) { { email: ["is invalid"], name: ["is too short"] } }

    before do
      errors.add(:name, "is required")
    end

    it "merges errors from another hash" do
      errors.merge!(other_errors)

      expect(errors[:name]).to contain_exactly("is required", "is too short")
      expect(errors[:email]).to eq(["is invalid"])
    end

    it "removes duplicate errors when merging" do
      errors.add(:age, "must be positive")
      duplicate_errors = { age: ["must be positive", "must be an integer"] }

      errors.merge!(duplicate_errors)

      expect(errors[:age]).to contain_exactly("must be positive", "must be an integer")
    end

    it "returns the merged errors hash" do
      result = errors.merge!(other_errors)

      expect(result).to be_a(Hash)
      expect(result[:email]).to eq(["is invalid"])
    end
  end

  describe "#messages_for" do
    before do
      errors.add(:name, "is required")
      errors.add(:name, "is too short")
    end

    it "returns raw messages for specific attribute" do
      result = errors.messages_for(:name)

      expect(result).to eq(["is required", "is too short"])
    end

    it "returns empty array for attribute without errors" do
      result = errors.messages_for(:missing)

      expect(result).to eq([])
    end
  end

  describe "#[]" do
    it "is an alias for messages_for" do
      errors.add(:status, "is pending")

      expect(errors[:status]).to eq(["is pending"])
    end
  end

  describe "#present?" do
    it "returns false when no errors present" do
      expect(errors.present?).to be false
    end

    it "returns true when errors are present" do
      errors.add(:name, "is required")

      expect(errors.present?).to be true
    end
  end

  describe "#to_hash" do
    before do
      errors.add(:name, "is required")
      errors.add(:email, "is invalid")
    end

    context "with default parameters" do
      it "returns hash of raw error messages" do
        result = errors.to_hash

        expect(result).to eq(
          {
            name: ["is required"],
            email: ["is invalid"]
          }
        )
      end
    end

    context "with full_messages parameter" do
      it "returns hash of formatted error messages when true" do
        result = errors.to_hash(true)

        expect(result).to eq(
          {
            name: ["name is required"],
            email: ["email is invalid"]
          }
        )
      end

      it "returns hash of raw messages when false" do
        result = errors.to_hash(false)

        expect(result).to eq(
          {
            name: ["is required"],
            email: ["is invalid"]
          }
        )
      end
    end

    context "with empty errors" do
      it "returns empty hash" do
        empty_errors = described_class.new

        expect(empty_errors.to_hash).to eq({})
      end
    end
  end

  describe "hash method aliases" do
    before do
      errors.add(:name, "is required")
    end

    it "#messages is alias for to_hash" do
      expect(errors.messages).to eq(errors.to_hash)
    end

    it "#group_by_attribute is alias for to_hash" do
      expect(errors.group_by_attribute).to eq(errors.to_hash)
    end

    it "#as_json is alias for to_hash" do
      expect(errors.as_json).to eq(errors.to_hash)
    end
  end

  describe "delegated methods" do
    before do
      errors.add(:name, "is required")
      errors.add(:email, "is invalid")
    end

    it "delegates clear" do
      errors.clear

      expect(errors).to be_empty
    end

    it "delegates delete" do
      errors.delete(:name)

      expect(errors.key?(:name)).to be false
      expect(errors.key?(:email)).to be true
    end

    it "delegates empty?" do
      expect(errors.empty?).to be false

      errors.clear
      expect(errors.empty?).to be true
    end

    it "delegates key?" do
      expect(errors.key?(:name)).to be true
      expect(errors.key?(:missing)).to be false
    end

    it "delegates keys" do
      expect(errors.keys).to contain_exactly(:name, :email)
    end

    it "delegates size" do
      expect(errors.size).to eq(2)
    end

    it "delegates values" do
      expect(errors.values).to contain_exactly(["is required"], ["is invalid"])
    end
  end

  describe "method aliases" do
    before do
      errors.add(:name, "is required")
    end

    it "#attribute_names is alias for keys" do
      expect(errors.attribute_names).to eq(errors.keys)
    end

    it "#blank? is alias for empty?" do
      expect(errors.blank?).to eq(errors.empty?)
    end

    it "#valid? is alias for empty?" do
      expect(errors.valid?).to eq(errors.empty?)
    end

    it "#has_key? is alias for key?" do
      expect(errors.has_key?(:name)).to eq(errors.key?(:name)) # rubocop:disable Style/PreferredHashMethods
    end

    it "#include? is alias for key?" do
      expect(errors.include?(:name)).to eq(errors.key?(:name))
    end
  end

  describe "state consistency" do
    it "maintains consistency between valid? and invalid?" do
      expect(errors.valid?).to eq(!errors.invalid?)

      errors.add(:test, "error")
      expect(errors.valid?).to eq(!errors.invalid?)
    end

    it "maintains consistency between blank? and present?" do
      expect(errors.blank?).to eq(!errors.present?)

      errors.add(:test, "error")
      expect(errors.blank?).to eq(!errors.present?)
    end
  end
end

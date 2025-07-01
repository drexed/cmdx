# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Errors do
  describe "#initialize" do
    it "creates an empty errors collection" do
      errors = described_class.new

      expect(errors.empty?).to be(true)
    end

    it "initializes with an empty internal hash" do
      errors = described_class.new

      expect(errors.errors).to eq({})
    end
  end

  describe "#add" do
    let(:errors) { described_class.new }

    it "adds an error message to an attribute" do
      errors.add(:email, "is required")

      expect(errors[:email]).to eq(["is required"])
    end

    it "adds multiple error messages to the same attribute" do
      errors.add(:email, "is required")
      errors.add(:email, "is invalid")

      expect(errors[:email]).to eq(["is required", "is invalid"])
    end

    it "deduplicates identical error messages" do
      errors.add(:email, "is required")
      errors.add(:email, "is required")

      expect(errors[:email]).to eq(["is required"])
    end

    it "handles string keys" do
      errors.add("email", "is required")

      expect(errors["email"]).to eq(["is required"])
    end

    it "modifies the errors collection" do
      errors.add(:email, "is required")

      expect(errors[:email]).to eq(["is required"])
    end

    it "handles multiple attributes independently" do
      errors.add(:email, "is required")
      errors.add(:password, "is too short")

      expect(errors[:email]).to eq(["is required"])
      expect(errors[:password]).to eq(["is too short"])
    end
  end

  describe "#[]=" do
    let(:errors) { described_class.new }

    it "acts as alias for add method" do
      errors[:email] = "is required"

      expect(errors[:email]).to eq(["is required"])
    end

    it "maintains same deduplication behavior" do
      errors[:email] = "is required"
      errors[:email] = "is required"

      expect(errors[:email]).to eq(["is required"])
    end
  end

  describe "#added?" do
    let(:errors) { described_class.new }

    context "when attribute has errors" do
      before do
        errors.add(:email, "is required")
        errors.add(:email, "is invalid")
      end

      it "returns true for existing error message" do
        expect(errors.added?(:email, "is required")).to be(true)
      end

      it "returns false for non-existing error message" do
        expect(errors.added?(:email, "is too long")).to be(false)
      end
    end

    context "when attribute has no errors" do
      it "returns false" do
        expect(errors.added?(:missing, "any message")).to be(false)
      end
    end

    it "handles string keys" do
      errors.add("email", "is required")

      expect(errors.added?("email", "is required")).to be(true)
    end
  end

  describe "#of_kind?" do
    let(:errors) { described_class.new }

    it "acts as alias for added? method" do
      errors.add(:email, "is required")

      expect(errors.of_kind?(:email, "is required")).to be(true)
      expect(errors.of_kind?(:email, "is invalid")).to be(false)
    end
  end

  describe "#each" do
    let(:errors) { described_class.new }

    context "when errors are present" do
      before do
        errors.add(:email, "is required")
        errors.add(:email, "is invalid")
        errors.add(:password, "is too short")
      end

      it "yields each attribute-message pair individually" do
        yielded_pairs = []
        errors.each { |key, val| yielded_pairs << [key, val] } # rubocop:disable Style/MapIntoArray

        expect(yielded_pairs).to contain_exactly(
          [:email, "is required"],
          [:email, "is invalid"],
          [:password, "is too short"]
        )
      end

      it "flattens multiple messages per attribute" do
        count = 0
        errors.each { |_, _| count += 1 }

        expect(count).to eq(3)
      end
    end

    context "when no errors are present" do
      it "does not yield any pairs" do
        yielded_count = 0
        errors.each { |_, _| yielded_count += 1 }

        expect(yielded_count).to eq(0)
      end
    end

    context "when no block is given" do
      it "raises LocalJumpError due to missing block" do
        errors.add(:email, "is required")

        expect { errors.each }.to raise_error(LocalJumpError, /no block given \(yield\)/)
      end
    end
  end

  describe "#full_message" do
    let(:errors) { described_class.new }

    it "combines attribute name and message" do
      result = errors.full_message(:email, "is required")

      expect(result).to eq("email is required")
    end

    it "handles string keys" do
      result = errors.full_message("password", "is too short")

      expect(result).to eq("password is too short")
    end

    it "preserves message formatting" do
      result = errors.full_message(:age, "must be a positive number")

      expect(result).to eq("age must be a positive number")
    end
  end

  describe "#full_messages" do
    let(:errors) { described_class.new }

    context "when errors are present" do
      before do
        errors.add(:email, "is required")
        errors.add(:email, "is invalid")
        errors.add(:password, "is too short")
      end

      it "returns array of all full error messages" do
        result = errors.full_messages

        expect(result).to contain_exactly(
          "email is required",
          "email is invalid",
          "password is too short"
        )
      end

      it "maintains consistent ordering within attributes" do
        errors.add(:name, "first error")
        errors.add(:name, "second error")

        messages = errors.full_messages
        name_messages = messages.select { |msg| msg.start_with?("name") }

        expect(name_messages).to eq(["name first error", "name second error"])
      end
    end

    context "when no errors are present" do
      it "returns empty array" do
        expect(errors.full_messages).to eq([])
      end
    end
  end

  describe "#to_a" do
    let(:errors) { described_class.new }

    it "acts as alias for full_messages" do
      errors.add(:email, "is required")

      expect(errors.to_a).to eq(errors.full_messages)
      expect(errors.to_a).to eq(["email is required"])
    end
  end

  describe "#full_messages_for" do
    let(:errors) { described_class.new }

    context "when attribute has errors" do
      before do
        errors.add(:email, "is required")
        errors.add(:email, "is invalid")
        errors.add(:password, "is too short")
      end

      it "returns full messages for specified attribute" do
        result = errors.full_messages_for(:email)

        expect(result).to eq(["email is required", "email is invalid"])
      end

      it "returns only messages for the specified attribute" do
        result = errors.full_messages_for(:password)

        expect(result).to eq(["password is too short"])
      end
    end

    context "when attribute has no errors" do
      it "returns empty array" do
        expect(errors.full_messages_for(:missing)).to eq([])
      end
    end

    it "handles string keys" do
      errors.add("email", "is required")

      expect(errors.full_messages_for("email")).to eq(["email is required"])
    end
  end

  describe "#invalid?" do
    let(:errors) { described_class.new }

    context "when errors are present" do
      before do
        errors.add(:email, "is required")
      end

      it "returns true" do
        expect(errors.invalid?).to be(true)
      end
    end

    context "when no errors are present" do
      it "returns false" do
        expect(errors.invalid?).to be(false)
      end
    end
  end

  describe "#merge!" do
    let(:errors) { described_class.new }

    context "when merging new attributes" do
      let(:hash_to_merge) { { password: ["is too short"], age: ["must be positive"] } }

      it "adds new error attributes" do
        errors.merge!(hash_to_merge)

        expect(errors[:password]).to eq(["is too short"])
        expect(errors[:age]).to eq(["must be positive"])
      end

      it "returns the updated errors hash" do
        result = errors.merge!(hash_to_merge)

        expect(result).to eq(errors.errors)
      end
    end

    context "when merging existing attributes" do
      before do
        errors.add(:email, "is required")
      end

      it "combines arrays of messages" do
        errors.merge!(email: ["is invalid", "is too long"]) # rubocop:disable Performance/RedundantMerge

        expect(errors[:email]).to contain_exactly("is required", "is invalid", "is too long")
      end

      it "deduplicates merged messages" do
        errors.merge!(email: ["is required", "is invalid"]) # rubocop:disable Performance/RedundantMerge

        expect(errors[:email]).to contain_exactly("is required", "is invalid")
      end
    end

    context "when merging mixed new and existing attributes" do
      before do
        errors.add(:email, "is required")
      end

      it "handles both cases correctly" do
        hash_to_merge = {
          email: ["is invalid"],
          password: ["is too short"]
        }
        errors.merge!(hash_to_merge)

        expect(errors[:email]).to contain_exactly("is required", "is invalid")
        expect(errors[:password]).to eq(["is too short"])
      end
    end

    context "when merging empty hash" do
      before do
        errors.add(:email, "is required")
      end

      it "does not change existing errors" do
        errors.merge!({})

        expect(errors[:email]).to eq(["is required"])
      end
    end
  end

  describe "#messages_for" do
    let(:errors) { described_class.new }

    context "when attribute has errors" do
      before do
        errors.add(:email, "is required")
        errors.add(:email, "is invalid")
      end

      it "returns array of error messages for attribute" do
        result = errors.messages_for(:email)

        expect(result).to eq(["is required", "is invalid"])
      end
    end

    context "when attribute has no errors" do
      it "returns empty array" do
        expect(errors.messages_for(:missing)).to eq([])
      end
    end

    it "handles string keys" do
      errors.add("email", "is required")

      expect(errors.messages_for("email")).to eq(["is required"])
    end
  end

  describe "#[]" do
    let(:errors) { described_class.new }

    it "acts as alias for messages_for" do
      errors.add(:email, "is required")

      expect(errors[:email]).to eq(errors.messages_for(:email))
      expect(errors[:email]).to eq(["is required"])
    end
  end

  describe "#present?" do
    let(:errors) { described_class.new }

    context "when errors are present" do
      before do
        errors.add(:email, "is required")
      end

      it "returns true" do
        expect(errors.present?).to be(true)
      end
    end

    context "when no errors are present" do
      it "returns false" do
        expect(errors.present?).to be(false)
      end
    end
  end

  describe "#to_hash" do
    let(:errors) { described_class.new }

    context "when full_messages is false" do
      before do
        errors.add(:email, "is required")
        errors.add(:password, "is too short")
      end

      it "returns hash with raw error messages" do
        result = errors.to_hash

        expect(result).to eq({
                               email: ["is required"],
                               password: ["is too short"]
                             })
      end

      it "returns copy of internal errors hash" do
        result = errors.to_hash

        expect(result).to eq(errors.errors)
      end
    end

    context "when full_messages is true" do
      before do
        errors.add(:email, "is required")
        errors.add(:email, "is invalid")
        errors.add(:password, "is too short")
      end

      it "returns hash with full formatted messages" do
        result = errors.to_hash(true)

        expect(result).to eq({
                               email: ["email is required", "email is invalid"],
                               password: ["password is too short"]
                             })
      end
    end

    context "when no errors are present" do
      it "returns empty hash for raw messages" do
        expect(errors.to_hash).to eq({})
      end

      it "returns empty hash for full messages" do
        expect(errors.to_hash(true)).to eq({})
      end
    end
  end

  describe "#messages" do
    let(:errors) { described_class.new }

    it "acts as alias for to_hash" do
      errors.add(:email, "is required")

      expect(errors.messages).to eq(errors.to_hash)
      expect(errors.messages(true)).to eq(errors.to_hash(true))
    end
  end

  describe "#group_by_attribute" do
    let(:errors) { described_class.new }

    it "acts as alias for to_hash" do
      errors.add(:email, "is required")

      expect(errors.group_by_attribute).to eq(errors.to_hash)
      expect(errors.group_by_attribute(true)).to eq(errors.to_hash(true))
    end
  end

  describe "#as_json" do
    let(:errors) { described_class.new }

    it "acts as alias for to_hash" do
      errors.add(:email, "is required")

      expect(errors.as_json).to eq(errors.to_hash)
      expect(errors.as_json(true)).to eq(errors.to_hash(true))
    end
  end

  describe "delegated methods" do
    let(:errors) { described_class.new }

    before do
      errors.add(:email, "is required")
      errors.add(:password, "is too short")
    end

    describe "#clear" do
      it "removes all errors" do
        errors.clear

        expect(errors.empty?).to be(true)
        expect(errors.errors).to eq({})
      end
    end

    describe "#delete" do
      it "removes specific attribute errors" do
        errors.delete(:email)

        expect(errors.key?(:email)).to be(false)
        expect(errors.key?(:password)).to be(true)
      end

      it "returns deleted value" do
        result = errors.delete(:email)

        expect(result).to eq(["is required"])
      end
    end

    describe "#empty?" do
      it "returns false when errors exist" do
        expect(errors.empty?).to be(false)
      end

      it "returns true when no errors exist" do
        errors.clear

        expect(errors.empty?).to be(true)
      end
    end

    describe "#key?" do
      it "returns true for existing attribute" do
        expect(errors.key?(:email)).to be(true)
      end

      it "returns false for non-existing attribute" do
        expect(errors.key?(:missing)).to be(false)
      end
    end

    describe "#keys" do
      it "returns array of error attribute names" do
        expect(errors.keys).to contain_exactly(:email, :password)
      end
    end

    describe "#size" do
      it "returns number of attributes with errors" do
        expect(errors.size).to eq(2)
      end

      it "returns zero when no errors" do
        errors.clear

        expect(errors.size).to eq(0)
      end
    end

    describe "#values" do
      it "returns array of all error message arrays" do
        values = errors.values

        expect(values).to contain_exactly(["is required"], ["is too short"])
      end
    end
  end

  describe "method aliases" do
    let(:errors) { described_class.new }

    before do
      errors.add(:email, "is required")
    end

    describe "#attribute_names" do
      it "acts as alias for keys" do
        expect(errors.attribute_names).to eq(errors.keys)
        expect(errors.attribute_names).to eq([:email])
      end
    end

    describe "#blank?" do
      it "acts as alias for empty?" do
        expect(errors.blank?).to eq(errors.empty?)
        expect(errors.blank?).to be(false)
      end
    end

    describe "#valid?" do
      it "acts as alias for empty?" do
        expect(errors.valid?).to eq(errors.empty?)
        expect(errors.valid?).to be(false)
      end
    end

    describe "#has_key?" do
      it "acts as alias for key?" do
        expect(errors.key?(:email)).to eq(errors.key?(:email))
        expect(errors.key?(:email)).to be(true)
      end
    end

    describe "#include?" do
      it "acts as alias for key?" do
        expect(errors.include?(:email)).to eq(errors.key?(:email))
        expect(errors.include?(:email)).to be(true)
      end
    end
  end

  describe "integration scenarios" do
    let(:errors) { described_class.new }

    context "when building complex error collections" do
      it "handles multiple error types efficiently" do
        # User validation errors
        errors.add(:email, "can't be blank")
        errors.add(:email, "is invalid")
        errors.add(:password, "is too short")
        errors.add(:password, "must contain special characters")

        # Address validation errors
        errors.add(:street, "is required")
        errors.add(:zip_code, "must be 5 digits")

        expect(errors.size).to eq(4)
        expect(errors.full_messages.length).to eq(6)
        expect(errors.invalid?).to be(true)
      end

      it "supports error querying and filtering" do
        errors.add(:email, "is required")
        errors.add(:email, "is invalid format")
        errors.add(:password, "is too short")

        email_errors = errors.full_messages_for(:email)
        password_errors = errors.messages_for(:password)

        expect(email_errors).to eq(["email is required", "email is invalid format"])
        expect(password_errors).to eq(["is too short"])
        expect(errors.added?(:email, "is required")).to be(true)
        expect(errors.added?(:password, "is invalid")).to be(false)
      end
    end

    context "when working with external error sources" do
      it "merges validation errors from multiple sources" do
        # Initial validation
        errors.add(:email, "is required")

        # External service validation
        external_errors = {
          email: ["already exists in system"],
          phone: ["invalid format", "not supported in region"]
        }
        errors.merge!(external_errors)

        expect(errors[:email]).to contain_exactly("is required", "already exists in system")
        expect(errors[:phone]).to eq(["invalid format", "not supported in region"])
        expect(errors.size).to eq(2)
      end

      it "converts to different output formats" do
        errors.add(:name, "can't be blank")
        errors.add(:age, "must be positive")

        raw_hash = errors.to_hash
        full_hash = errors.to_hash(true)
        json_output = errors.as_json
        messages_output = errors.messages

        expect(raw_hash).to eq({ name: ["can't be blank"], age: ["must be positive"] })
        expect(full_hash).to eq({ name: ["name can't be blank"], age: ["age must be positive"] })
        expect(json_output).to eq(raw_hash)
        expect(messages_output).to eq(raw_hash)
      end
    end

    context "when managing validation state" do
      it "provides comprehensive validation status checking" do
        # Empty state
        expect(errors.valid?).to be(true)
        expect(errors.invalid?).to be(false)
        expect(errors.blank?).to be(true)
        expect(errors.present?).to be(false)

        # With errors
        errors.add(:email, "is invalid")

        expect(errors.valid?).to be(false)
        expect(errors.invalid?).to be(true)
        expect(errors.blank?).to be(false)
        expect(errors.present?).to be(true)
      end
    end
  end
end

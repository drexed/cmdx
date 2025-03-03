# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Errors do
  subject(:errors) { described_class.new }

  describe ".initialize" do
    it "returns []" do
      expect(errors.errors).to eq({})
    end
  end

  describe ".[]" do
    it "returns []" do
      expect(errors[:field]).to eq([])
    end

    it 'returns ["error message"]' do
      errors.add(:field, "error message")

      expect(errors[:field]).to eq(["error message"])
    end
  end

  describe ".add" do
    it 'returns { field: ["error message", "other message"] }' do
      2.times { errors.add(:field, "error message") }
      errors.add(:field, "other message")

      expect(errors.errors).to eq(field: ["error message", "other message"])
    end
  end

  describe ".added?" do
    before { errors.add(:field, "error message") }

    it "returns true" do
      expect(errors.added?(:field, "error message")).to be(true)
    end

    it "returns false with missing key" do
      expect(errors.added?(:other, "error message")).to be(false)
    end

    it "returns false with missing message" do
      expect(errors.added?(:field, "other message")).to be(false)
    end
  end

  describe ".clear" do
    it "returns {}" do
      errors.add(:field, "error message")

      expect(errors.clear).to eq({})
    end
  end

  describe ".delete" do
    it 'returns "error message"' do
      errors.add(:field, "error message")

      expect(errors.delete(:field)).to eq(["error message"])
    end
  end

  describe ".empty?" do
    it "returns true" do
      expect(errors.empty?).to be(true)
    end

    it "returns false" do
      errors.add(:field, "error message")

      expect(errors.empty?).to be(false)
    end
  end

  describe ".full_message" do
    it 'returns "field error message"' do
      expect(errors.full_message(:field, "error message")).to eq("field error message")
    end
  end

  describe ".full_messages" do
    it 'returns "field error message"' do
      errors.add(:field, "error message")
      errors.add(:field, "other message")

      expect(errors.full_messages).to eq(["field error message", "field other message"])
    end
  end

  describe ".full_messages_for" do
    it "returns []" do
      expect(errors.full_messages_for(:field)).to eq([])
    end

    it 'returns ["field error message"]' do
      errors.add(:field, "error message")
      errors.add(:other, "other message")

      expect(errors.full_messages_for(:field)).to eq(["field error message"])
    end
  end

  describe ".key?" do
    it "returns false" do
      expect(errors.key?(:field)).to be(false)
    end

    it "returns true" do
      errors.add(:field, "error message")

      expect(errors.key?(:field)).to be(true)
    end
  end

  describe ".keys" do
    it "returns [:field]" do
      errors.add(:field, "error message")

      expect(errors.keys).to eq(%i[field])
    end
  end

  # rubocop:disable Performance/RedundantMerge
  describe ".merge!" do
    it 'returns { field: ["error message", "other message"] }' do
      # Skip fasterer error: Hash#merge!

      errors.add(:field, "error message")
      errors.merge!(field: ["error message"])
      errors.merge!(field: ["other message"])

      expect(errors.errors).to eq(field: ["error message", "other message"])
    end
  end
  # rubocop:enable Performance/RedundantMerge

  describe ".present?" do
    it "returns false" do
      expect(errors.present?).to be(false)
    end

    it "returns true" do
      errors.add(:field, "error message")

      expect(errors.present?).to be(true)
    end
  end

  describe ".size" do
    it "returns 0" do
      expect(errors.size).to eq(0)
    end

    it "returns 1" do
      errors.add(:field, "error message")

      expect(errors.size).to eq(1)
    end
  end

  describe ".to_hash" do
    before { errors.add(:field, "error message") }

    it 'returns { field: ["error message"] }' do
      expect(errors.to_hash).to eq(field: ["error message"])
    end

    it 'returns { field: ["field error message"] }' do
      expect(errors.to_hash(true)).to eq(field: ["field error message"])
    end
  end

  describe ".values" do
    it 'returns [["error message"]]' do
      errors.add(:field, "error message")

      expect(errors.values).to eq([["error message"]])
    end
  end

end

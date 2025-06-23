# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Errors do
  subject(:errors) { described_class.new }

  let(:field_key) { :field }
  let(:error_message) { "error message" }
  let(:other_message) { "other message" }

  describe "#initialize" do
    it "initializes with empty errors hash" do
      expect(errors.errors).to eq({})
    end
  end

  describe "#[]" do
    context "when field has no errors" do
      it "returns empty array" do
        expect(errors[field_key]).to eq([])
      end
    end

    context "when field has errors" do
      before { errors.add(field_key, error_message) }

      it "returns array of error messages" do
        expect(errors[field_key]).to eq([error_message])
      end
    end
  end

  describe "#add" do
    it "accumulates multiple error messages for the same field" do
      2.times { errors.add(field_key, error_message) }
      errors.add(field_key, other_message)

      expect(errors.errors).to eq(field_key => [error_message, other_message])
    end
  end

  describe "#added?" do
    context "when error exists" do
      before { errors.add(field_key, error_message) }

      it "returns true for existing error" do
        expect(errors.added?(field_key, error_message)).to be(true)
      end

      it "returns false for different field" do
        expect(errors.added?(:other, error_message)).to be(false)
      end

      it "returns false for different message" do
        expect(errors.added?(field_key, other_message)).to be(false)
      end
    end
  end

  describe "#clear" do
    it "clears all errors and returns empty hash" do
      errors.add(field_key, error_message)

      expect(errors.clear).to eq({})
    end
  end

  describe "#delete" do
    it "removes and returns error messages for field" do
      errors.add(field_key, error_message)

      expect(errors.delete(field_key)).to eq([error_message])
    end
  end

  describe "#empty?" do
    context "when no errors exist" do
      it "returns true" do
        expect(errors.empty?).to be(true)
      end
    end

    context "when errors exist" do
      before { errors.add(field_key, error_message) }

      it "returns false" do
        expect(errors.empty?).to be(false)
      end
    end
  end

  describe "#full_message" do
    it "combines field name with error message" do
      expect(errors.full_message(field_key, error_message)).to eq("field error message")
    end
  end

  describe "#full_messages" do
    it "returns all full messages for all fields" do
      errors.add(field_key, error_message)
      errors.add(field_key, other_message)

      expect(errors.full_messages).to eq(["field error message", "field other message"])
    end
  end

  describe "#full_messages_for" do
    context "when field has no errors" do
      it "returns empty array" do
        expect(errors.full_messages_for(field_key)).to eq([])
      end
    end

    context "when field has errors" do
      before do
        errors.add(field_key, error_message)
        errors.add(:other, other_message)
      end

      it "returns full messages only for specified field" do
        expect(errors.full_messages_for(field_key)).to eq(["field error message"])
      end
    end
  end

  describe "#key?" do
    context "when field has no errors" do
      it "returns false" do
        expect(errors.key?(field_key)).to be(false)
      end
    end

    context "when field has errors" do
      before { errors.add(field_key, error_message) }

      it "returns true" do
        expect(errors.key?(field_key)).to be(true)
      end
    end
  end

  describe "#keys" do
    it "returns array of field keys with errors" do
      errors.add(field_key, error_message)

      expect(errors.keys).to eq([field_key])
    end
  end

  # rubocop:disable Performance/RedundantMerge
  describe "#merge!" do
    it "merges error messages for fields" do
      # Skip fasterer error: Hash#merge!

      errors.add(field_key, error_message)
      errors.merge!(field_key => [error_message])
      errors.merge!(field_key => [other_message])

      expect(errors.errors).to eq(field_key => [error_message, other_message])
    end
  end
  # rubocop:enable Performance/RedundantMerge

  describe "#present?" do
    context "when no errors exist" do
      it "returns false" do
        expect(errors.present?).to be(false)
      end
    end

    context "when errors exist" do
      before { errors.add(field_key, error_message) }

      it "returns true" do
        expect(errors.present?).to be(true)
      end
    end
  end

  describe "#size" do
    context "when no errors exist" do
      it "returns 0" do
        expect(errors.size).to eq(0)
      end
    end

    context "when errors exist" do
      before { errors.add(field_key, error_message) }

      it "returns number of fields with errors" do
        expect(errors.size).to eq(1)
      end
    end
  end

  describe "#to_hash" do
    before { errors.add(field_key, error_message) }

    context "when full_messages is false" do
      it "returns hash with raw error messages" do
        expect(errors.to_hash).to eq(field_key => [error_message])
      end
    end

    context "when full_messages is true" do
      it "returns hash with full error messages" do
        expect(errors.to_hash(true)).to eq(field_key => ["field error message"])
      end
    end
  end

  describe "#values" do
    it "returns array of error message arrays" do
      errors.add(field_key, error_message)

      expect(errors.values).to eq([[error_message]])
    end
  end
end

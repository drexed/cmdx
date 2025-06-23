# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Inclusion do
  subject(:validator) { described_class.call(value, options) }

  let(:validator_key) { :inclusion }
  let(:base_options) { { inclusion: { in: ["a", 1, Float] } } }
  let(:options) { base_options }

  # Collection validator configuration
  let(:collection_valid_value) { 1 }
  let(:collection_invalid_value) { "b" }
  let(:expected_collection_message) { 'must be one of: "a", 1, Float' }

  it_behaves_like "a collection validator"

  context "when validating against type classes" do
    let(:value) { 2.0 }

    it "returns nil for valid type instance" do
      expect(validator).to be_nil
    end
  end

  context "when using range inclusion" do
    let(:options) { { inclusion: { in: 0..2 } } }

    context "when value is within range" do
      let(:value) { 1 }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value is outside range" do
      let(:options) { { inclusion: { in: 2..4 } } }
      let(:value) { 1 }

      it "raises ValidationError with range message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "must be within 2 and 4")
      end
    end
  end
end

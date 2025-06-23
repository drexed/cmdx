# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Exclusion do
  subject(:validator) { described_class.call(value, options) }

  let(:validator_key) { :exclusion }
  let(:base_options) { { exclusion: { in: [1, String] } } }
  let(:options) { base_options }

  # Collection validator configuration (inverted logic for exclusion)
  let(:collection_valid_value) { 2 }
  let(:collection_invalid_value) { "b" }
  let(:expected_collection_message) { "must not be one of: 1, String" }

  it_behaves_like "a collection validator"

  context "when using range exclusion" do
    let(:options) { { exclusion: { in: 2..4 } } }

    context "when value is outside excluded range" do
      let(:value) { 1 }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value is within excluded range" do
      let(:options) { { exclusion: { in: 0..2 } } }
      let(:value) { 1 }

      it "raises ValidationError with range message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "must not be within 0 and 2")
      end
    end
  end
end

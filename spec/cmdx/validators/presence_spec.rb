# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Presence do
  subject(:validator) { described_class.call(value, options) }

  let(:base_options) { { presence: true } }
  let(:options) { base_options }
  let(:validator_key) { :presence }
  let(:expected_default_message) { "cannot be empty" }

  context "when value is present" do
    let(:value) { 3 }

    it "returns nil without raising error" do
      expect(validator).to be_nil
    end
  end

  context "when value is empty" do
    let(:value) { [] }

    context "with default message" do
      it "raises ValidationError with default message" do
        expect { validator }.to raise_error(CMDx::ValidationError, expected_default_message)
      end
    end

    context "with custom message" do
      let(:options) { { presence: { message: "custom message" } } }

      it "raises ValidationError with custom message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
      end
    end
  end
end

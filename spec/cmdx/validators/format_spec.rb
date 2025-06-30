# frozen_string_literal: true

require "spec_helper"
require "uri"

RSpec.describe CMDx::Validators::Format do
  subject(:validator) { described_class.call(value, options) }

  let(:validator_key) { :format }
  let(:base_options) { { format: { with: URI::MailTo::EMAIL_REGEXP } } }
  let(:options) { base_options }
  let(:valid_value) { "example@test.com" }
  let(:invalid_value) { "example" }
  let(:expected_default_message) { "is an invalid format" }

  context "when using 'with' pattern matching" do
    context "when value matches pattern" do
      let(:value) { valid_value }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value does not match pattern" do
      let(:value) { invalid_value }

      context "when using default message" do
        it "raises ValidationError with default message" do
          expect { validator }.to raise_error(CMDx::ValidationError, expected_default_message)
        end
      end

      context "when using custom message" do
        let(:options) { base_options.merge(validator_key => base_options[validator_key].merge(message: "custom message")) }

        it "raises ValidationError with custom message" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end
  end

  context "when using 'without' pattern exclusion" do
    let(:options) { { format: { without: URI::MailTo::EMAIL_REGEXP } } }

    context "when value does not match excluded pattern" do
      let(:value) { invalid_value }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value matches excluded pattern" do
      let(:value) { valid_value }

      context "when using default message" do
        it "raises ValidationError with default message" do
          expect { validator }.to raise_error(CMDx::ValidationError, expected_default_message)
        end
      end

      context "when using custom message" do
        let(:options) { { format: { without: URI::MailTo::EMAIL_REGEXP, message: "custom message" } } }

        it "raises ValidationError with custom message" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end
  end
end

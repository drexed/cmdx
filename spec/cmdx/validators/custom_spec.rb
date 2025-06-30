# frozen_string_literal: true

require "spec_helper"
require "uri"

RSpec.describe CMDx::Validators::Custom do
  subject(:validator) { described_class.call(value, options) }

  let(:custom_validator) do
    Class.new do
      def self.call(value, options)
        value == options.dig(:custom, :is)
      end
    end
  end

  let(:validator_key) { :custom }
  let(:base_options) { { custom: { validator: custom_validator, is: 123 } } }
  let(:options) { base_options }
  let(:valid_value) { 123 }
  let(:invalid_value) { 456 }
  let(:expected_default_message) { "is not valid" }

  context "when using custom validator logic" do
    context "when value passes custom validation" do
      let(:value) { valid_value }

      it "returns nil without raising error" do
        expect(validator).to be_nil
      end
    end

    context "when value fails custom validation" do
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

  context "when using localized error messages" do
    let(:value) { invalid_value }

    context "when using :en locale" do
      it "raises ValidationError with English message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "is not valid")
      end
    end

    context "when using :es locale" do
      before { I18n.locale = :es }
      after { I18n.locale = :en }

      it "raises ValidationError with Spanish message" do
        expect { validator }.to raise_error(CMDx::ValidationError, "no es válida")
      end
    end
  end
end

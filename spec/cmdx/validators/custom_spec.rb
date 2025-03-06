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
  let(:options) do
    {
      custom: { validator: custom_validator, is: 123 }
    }
  end

  describe ".call" do
    context "when valid" do
      let(:value) { 123 }

      it "returns successfully" do
        expect(validator).to be_nil
      end
    end

    context "when invalid" do
      let(:value) { 456 }

      context "with default message" do
        context "when :en locale" do
          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "is not valid")
          end
        end

        context "when :es locale" do
          before { I18n.locale = :es }
          after { I18n.locale = :en }

          it "raises a ValidationError" do
            expect { validator }.to raise_error(CMDx::ValidationError, "no es válida")
          end
        end
      end

      context "with custom message" do
        let(:options) do
          {
            custom: {
              validator: custom_validator,
              is: 123,
              message: "custom message"
            }
          }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end
  end
end

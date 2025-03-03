# frozen_string_literal: true

require "spec_helper"
require "uri"

RSpec.describe CMDx::Validators::Format do
  subject(:validator) { described_class.call(value, options) }

  let(:value) { "example@test.com" }
  let(:options) do
    { format: { with: URI::MailTo::EMAIL_REGEXP } }
  end

  describe ".call" do
    context "when valid" do
      it "returns successfully" do
        expect(validator).to be_nil
      end
    end

    context "when invalid" do
      let(:value) { "example" }

      context "with default message" do
        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "is an invalid format")
        end
      end

      context "with custom message" do
        let(:options) do
          { format: { with: URI::MailTo::EMAIL_REGEXP, message: "custom message" } }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end

    context "with without" do
      let(:options) do
        { format: { without: URI::MailTo::EMAIL_REGEXP } }
      end

      context "with default message" do
        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "is an invalid format")
        end
      end

      context "with custom message" do
        let(:options) do
          { format: { without: URI::MailTo::EMAIL_REGEXP, message: "custom message" } }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end
  end

end

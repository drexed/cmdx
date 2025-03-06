# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Presence do
  subject(:validator) { described_class.call(value, options) }

  let(:options) do
    { presence: true }
  end

  describe ".call" do
    context "when valid" do
      let(:value) { 3 }

      it "returns successfully" do
        expect(validator).to be_nil
      end
    end

    context "when invalid" do
      let(:value) { [] }

      context "with default message" do
        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "cannot be empty")
        end
      end

      context "with custom message" do
        let(:options) do
          { presence: { message: "custom message" } }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end
  end
end

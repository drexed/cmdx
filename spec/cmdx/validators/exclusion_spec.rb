# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Exclusion do
  subject(:validator) { described_class.call(value, options) }

  let(:value) { 1 }
  let(:options) do
    { exclusion: { in: [1, String] } }
  end

  describe ".call" do
    context "when valid" do
      let(:value) { 2 }

      it "returns successfully" do
        expect(validator).to be_nil
      end
    end

    context "when invalid" do
      let(:value) { "b" }

      context "with default message" do
        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "must not be one of: 1, String")
        end
      end

      context "with custom message" do
        let(:options) do
          { exclusion: { in: [1, String], message: "custom message" } }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end

    context "with range" do
      let(:options) do
        { exclusion: { in: 2..4 } }
      end

      context "when valid" do
        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        let(:options) do
          { exclusion: { in: 0..2 } }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "must not be within 0 and 2")
        end
      end
    end
  end

end

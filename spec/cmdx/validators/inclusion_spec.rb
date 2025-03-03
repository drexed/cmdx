# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Inclusion do
  subject(:validator) { described_class.call(value, options) }

  let(:value) { 1 }
  let(:options) do
    { inclusion: { in: ["a", 1, Float] } }
  end

  describe ".call" do
    context "when valid match" do
      let(:value) { 1 }

      it "returns successfully" do
        expect(validator).to be_nil
      end
    end

    context "when valid type" do
      let(:value) { 2.0 }

      it "returns successfully" do
        expect(validator).to be_nil
      end
    end

    context "when invalid" do
      let(:value) { "b" }

      context "with default message" do
        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, 'must be one of: "a", 1, Float')
        end
      end

      context "with custom message" do
        let(:options) do
          { inclusion: { in: ["a", 1, Float], message: "custom message" } }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "custom message")
        end
      end
    end

    context "with range" do
      let(:options) do
        { inclusion: { in: 0..2 } }
      end

      context "when valid" do
        it "returns successfully" do
          expect(validator).to be_nil
        end
      end

      context "when invalid" do
        let(:options) do
          { inclusion: { in: 2..4 } }
        end

        it "raises a ValidationError" do
          expect { validator }.to raise_error(CMDx::ValidationError, "must be within 2 and 4")
        end
      end
    end
  end

end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Complex do
  subject(:coercion) { described_class.call(value) }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end
    end

    context "when invalid" do
      let(:value) { "abc123" }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a complex")
      end
    end

    context "when numeric" do
      let(:value) { 1.2 }

      it "returns a complex" do
        expect(coercion).to be_a(Complex)
      end
    end
  end
end

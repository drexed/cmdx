# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::BigDecimal do
  subject(:coercion) { described_class.call(value) }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end
    end

    context "when invalid" do
      let(:value) { "abc123" }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a big decimal")
      end
    end

    context "when numeric" do
      let(:value) { 1.2 }

      it "returns a big decimal" do
        expect(coercion).to be_a(BigDecimal)
      end
    end
  end
end

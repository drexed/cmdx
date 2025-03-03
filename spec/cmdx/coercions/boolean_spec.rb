# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Boolean do
  subject(:coercion) { described_class.call(value) }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end
    end

    context "when invalid" do
      let(:value) { "abc123" }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a boolean")
      end
    end

    context "when truthy" do
      let(:value) { "t" }

      it "returns true" do
        expect(coercion).to be(true)
      end
    end

    context "when falsey" do
      let(:value) { "f" }

      it "returns false" do
        expect(coercion).to be(false)
      end
    end
  end

end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Virtual do
  subject(:coercion) { described_class.call(value) }

  describe ".call" do
    context "when value is provided" do
      let(:value) { 42 }

      it "returns the value unchanged" do
        expect(coercion).to eq(42)
      end
    end

    context "when value is nil" do
      let(:value) { nil }

      it "returns nil unchanged" do
        expect(coercion).to be_nil
      end
    end

    context "when value is complex object" do
      let(:value) { { a: 1, b: [2, 3] } }

      it "returns the object unchanged" do
        expect(coercion).to eq({ a: 1, b: [2, 3] })
      end
    end
  end
end

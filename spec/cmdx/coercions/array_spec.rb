# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Array do
  subject(:coercion) { described_class.call(value) }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "returns an empty array" do
        expect(coercion).to eq([])
      end
    end

    context "when array" do
      let(:value) { [] }

      it "returns the array" do
        expect(coercion).to eq([])
      end
    end

    context "when object" do
      let(:value) { 1 }

      it "returns the object wrap in an array" do
        expect(coercion).to eq([1])
      end
    end

    context "when json" do
      let(:value) { "[1,2,\"b\"]" }

      it "returns an array" do
        expect(coercion).to eq([1, 2, "b"])
      end
    end
  end
end

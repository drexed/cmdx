# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::String do
  subject(:coercion) { described_class.call(value) }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "returns a empty string" do
        expect(coercion).to eq("")
      end
    end

    context "when string" do
      let(:value) { "a" }

      it "returns the string" do
        expect(coercion).to eq("a")
      end
    end

    context "when object" do
      let(:value) { 1 }

      it "returns the object as a string" do
        expect(coercion).to eq("1")
      end
    end
  end

end

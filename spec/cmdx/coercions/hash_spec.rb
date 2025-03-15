# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Hash do
  subject(:coercion) { described_class.call(value) }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "when invalid" do
      let(:value) { "abc123" }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a hash")
      end
    end

    context "when hash" do
      let(:value) { { a: 1 } }

      it "returns the hash" do
        expect(coercion).to be_a(Hash)
      end
    end

    context "when array" do
      let(:value) { [:a, 1, :b, 2] }

      it "returns a hash" do
        expect(coercion).to eq({ a: 1, b: 2 })
      end
    end

    context "when json" do
      let(:value) { "{\"a\":1,\"b\":2}" }

      it "returns a hash" do
        expect(coercion).to eq({ "a" => 1, "b" => 2 })
      end
    end
  end
end

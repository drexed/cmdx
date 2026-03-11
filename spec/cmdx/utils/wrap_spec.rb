# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Wrap, type: :unit do
  subject(:wrap_module) { described_class }

  describe ".array" do
    context "when object is already an array" do
      it "returns the same array" do
        array = [1, 2, 3]
        result = wrap_module.array(array)

        expect(result).to be(array)
      end

      it "returns an empty array as-is" do
        result = wrap_module.array([])

        expect(result).to eq([])
      end
    end

    context "when object is nil" do
      it "returns an empty array" do
        result = wrap_module.array(nil)

        expect(result).to eq([])
      end
    end

    context "when object is a single value" do
      it "wraps an integer" do
        result = wrap_module.array(1)

        expect(result).to eq([1])
      end

      it "wraps a string" do
        result = wrap_module.array("hello")

        expect(result).to eq(["hello"])
      end

      it "wraps a symbol" do
        result = wrap_module.array(:foo)

        expect(result).to eq([:foo])
      end
    end

    context "when object is a hash" do
      it "wraps the hash in an array" do
        result = wrap_module.array({ a: 1, b: 2 })

        expect(result).to eq([[:a, 1], [:b, 2]])
      end
    end
  end
end

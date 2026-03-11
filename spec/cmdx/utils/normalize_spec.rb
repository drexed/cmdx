# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Normalize, type: :unit do
  subject(:normalize_module) { described_class }

  describe ".exception" do
    context "when given a standard error" do
      it "returns class and message in bracket format" do
        error = StandardError.new("something went wrong")
        result = normalize_module.exception(error)

        expect(result).to eq("[StandardError] something went wrong")
      end
    end

    context "when given a custom error class" do
      it "includes the full class name" do
        error = ArgumentError.new("bad argument")
        result = normalize_module.exception(error)

        expect(result).to eq("[ArgumentError] bad argument")
      end
    end

    context "when given an error with an empty message" do
      it "returns the class with an empty message" do
        error = RuntimeError.new("")
        result = normalize_module.exception(error)

        expect(result).to eq("[RuntimeError] ")
      end
    end
  end

  describe ".statuses" do
    context "when object is an array of symbols" do
      it "returns unique string representations" do
        result = normalize_module.statuses(%i[success pending success])

        expect(result).to eq(%w[success pending])
      end
    end

    context "when object is an array of strings" do
      it "returns unique strings" do
        result = normalize_module.statuses(%w[success pending success])

        expect(result).to eq(%w[success pending])
      end
    end

    context "when object is an array of mixed types" do
      it "converts all to strings and deduplicates" do
        result = normalize_module.statuses([:success, "success"])

        expect(result).to eq(["success"])
      end
    end

    context "when object is a single symbol" do
      it "returns a single-element string array" do
        result = normalize_module.statuses(:success)

        expect(result).to eq(["success"])
      end
    end

    context "when object is a single string" do
      it "returns a single-element string array" do
        result = normalize_module.statuses("pending")

        expect(result).to eq(["pending"])
      end
    end

    context "when object is nil" do
      it "returns an empty array" do
        result = normalize_module.statuses(nil)

        expect(result).to eq([])
      end
    end

    context "when object is an empty array" do
      it "returns an empty array" do
        result = normalize_module.statuses([])

        expect(result).to eq([])
      end
    end
  end
end

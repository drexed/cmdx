# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Exclusion do
  describe ".call" do
    it "raises without :in or :within" do
      expect { described_class.call(1) }.to raise_error(ArgumentError, /:in or :within/)
    end

    context "with an array" do
      it "passes when the value is not in the list" do
        expect(described_class.call(:c, in: %i[a b])).to be_nil
      end

      it "fails when the value is in the list" do
        expect(described_class.call(:a, in: %i[a b])).to be_a(CMDx::Validators::Failure)
      end

      it "interpolates :values into a custom message" do
        f = described_class.call(:a, in: %i[a b], message: "not %{values}")
        expect(f.message).to include(":a")
      end
    end

    context "with a range" do
      it "passes when outside the range" do
        expect(described_class.call(5, within: 1..3)).to be_nil
      end

      it "fails when inside the range" do
        expect(described_class.call(2, within: 1..3)).to be_a(CMDx::Validators::Failure)
      end

      it "interpolates :min/:max into a custom within_message" do
        f = described_class.call(2, within: 1..3, within_message: "%{min}..%{max}")
        expect(f.message).to eq("1..3")
      end
    end
  end
end

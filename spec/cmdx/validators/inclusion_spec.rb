# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Validators::Inclusion do
  describe ".call" do
    it "raises without :in or :within" do
      expect { described_class.call(1) }.to raise_error(ArgumentError, /:in or :within/)
    end

    context "with an array" do
      it "passes when the value is in the list" do
        expect(described_class.call(:a, in: %i[a b])).to be_nil
      end

      it "fails when the value is not in the list" do
        expect(described_class.call(:c, in: %i[a b])).to be_a(CMDx::Validators::Failure)
      end
    end

    context "with a range" do
      it "passes when inside" do
        expect(described_class.call(2, within: 1..3)).to be_nil
      end

      it "fails when outside" do
        expect(described_class.call(9, within: 1..3)).to be_a(CMDx::Validators::Failure)
      end

      it "uses within_message with interpolation" do
        f = described_class.call(9, within: 1..3, within_message: "%{min}-%{max}")
        expect(f.message).to eq("1-3")
      end
    end
  end
end

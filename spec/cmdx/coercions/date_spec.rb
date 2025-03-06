# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Date do
  subject(:coercion) { described_class.call(value, options) }

  let(:options) { {} }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end
    end

    context "when invalid" do
      let(:value) { "abc" }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a date")
      end
    end

    context "when Date" do
      let(:value) { Date.new }

      it "returns the date" do
        expect(coercion).to be_a(Date)
      end
    end

    context "with format" do
      let(:options) { { format: "%Y-%m-%d" } }

      context "when valid" do
        let(:value) { "2001-02-03" }

        it "returns a date" do
          expect(coercion).to be_a(Date)
        end
      end

      context "when invalid" do
        let(:value) { "123" }

        it "raises a CoercionError" do
          expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a date")
        end
      end
    end
  end
end

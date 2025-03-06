# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Time do
  subject(:coercion) { described_class.call(value, options) }

  let(:options) { {} }

  describe ".call" do
    context "when nil" do
      let(:value) { nil }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end
    end

    context "when invalid" do
      let(:value) { "abc" }

      it "raises a CoercionError" do
        expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a time")
      end
    end

    context "when Time" do
      let(:value) { Time.new }

      it "returns the time" do
        expect(coercion).to be_a(Time)
      end
    end

    context "with format" do
      let(:options) { { format: "%Y-%m-%d" } }

      context "when valid" do
        let(:value) { "2001-02-03" }

        it "returns a time" do
          expect(coercion).to be_a(Time)
        end
      end

      context "when invalid" do
        let(:value) { "123" }

        it "raises a CoercionError" do
          expect { coercion }.to raise_error(CMDx::CoercionError, "could not coerce into a time")
        end
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Rational do
  describe "#call" do
    context "with rational values" do
      it "returns Rational unchanged" do
        rational = Rational(3, 4)
        expect(described_class.call(rational)).to eq(rational)
      end

      it "returns negative Rational unchanged" do
        rational = Rational(-3, 4)
        expect(described_class.call(rational)).to eq(rational)
      end
    end

    context "with string values" do
      it "converts fraction string to Rational" do
        result = described_class.call("3/4")
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 4))
      end

      it "converts negative fraction string to Rational" do
        result = described_class.call("-3/4")
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(-3, 4))
      end

      it "converts decimal string to Rational" do
        result = described_class.call("0.75")
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 4))
      end

      it "converts integer string to Rational" do
        result = described_class.call("5")
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(5, 1))
      end

      it "raises CoercionError for invalid string" do
        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for empty string" do
        expect do
          described_class.call("")
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with numeric values" do
      it "converts integer to Rational" do
        result = described_class.call(5)
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(5, 1))
      end

      it "converts negative integer to Rational" do
        result = described_class.call(-5)
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(-5, 1))
      end

      it "converts zero to Rational" do
        result = described_class.call(0)
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(0, 1))
      end

      it "converts float to Rational" do
        result = described_class.call(0.75)
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 4))
      end

      it "converts negative float to Rational" do
        result = described_class.call(-0.25)
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(-1, 4))
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect do
          described_class.call(true)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for false" do
        expect do
          described_class.call(false)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect do
          described_class.call(nil)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with array values" do
      it "raises CoercionError for empty array" do
        expect do
          described_class.call([])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for non-empty array" do
        expect do
          described_class.call([3, 4])
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with hash values" do
      it "raises CoercionError for empty hash" do
        expect do
          described_class.call({})
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end

      it "raises CoercionError for non-empty hash" do
        expect do
          described_class.call({ numerator: 3, denominator: 4 })
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with symbol values" do
      it "raises CoercionError for symbol" do
        expect do
          described_class.call(:test)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with object values" do
      it "raises CoercionError for object" do
        expect do
          described_class.call(Object.new)
        end.to raise_error(CMDx::CoercionError, /could not coerce into a rational/)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = described_class.call("3/4", { key: "value" })
        expect(result).to eq(Rational(3, 4))
      end

      it "works with empty options" do
        result = described_class.call(5, {})
        expect(result).to eq(Rational(5, 1))
      end

      it "works with nil options" do
        result = described_class.call("1/2", nil)
        expect(result).to eq(Rational(1, 2))
      end
    end

    context "with I18n translation" do
      it "uses I18n translation when available" do
        allow(I18n).to receive(:t).with("cmdx.coercions.into_a", type: "rational", default: "could not coerce into a rational").and_return("translated error")

        expect do
          described_class.call("invalid")
        end.to raise_error(CMDx::CoercionError, "translated error")
      end
    end

    context "with edge cases" do
      it "handles very large numerator and denominator" do
        result = described_class.call("999999999999999999999/1000000000000000000000")
        expect(result).to be_a(Rational)
      end

      it "handles fraction with common factors" do
        result = described_class.call("6/8")
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(3, 4))
      end

      it "handles improper fractions" do
        result = described_class.call("5/3")
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(5, 3))
      end

      it "raises ZeroDivisionError for division by zero" do
        expect do
          described_class.call("1/0")
        end.to raise_error(ZeroDivisionError)
      end

      it "handles scientific notation" do
        result = described_class.call("1e-3")
        expect(result).to be_a(Rational)
        expect(result).to eq(Rational(1, 1000))
      end
    end
  end
end

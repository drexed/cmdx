# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Float do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("3.14")).to eq(3.14)
    end
  end

  describe "#call" do
    context "with string values" do
      it "converts numeric strings to floats" do
        result = coercion.call("3.14")

        expect(result).to eq(3.14)
      end

      it "converts integer strings to floats" do
        result = coercion.call("42")

        expect(result).to eq(42.0)
      end

      it "converts zero strings to floats" do
        result = coercion.call("0")

        expect(result).to eq(0.0)
      end

      it "converts negative number strings to floats" do
        result = coercion.call("-3.14")

        expect(result).to eq(-3.14)
      end

      it "converts scientific notation strings to floats" do
        result = coercion.call("1.23e-4")

        expect(result).to eq(0.000123)
      end

      it "raises CoercionError for infinity strings" do
        expect { coercion.call("Infinity") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for negative infinity strings" do
        expect { coercion.call("-Infinity") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for NaN strings" do
        expect { coercion.call("NaN") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "handles leading and trailing whitespace" do
        result = coercion.call("  3.14  ")

        expect(result).to eq(3.14)
      end

      it "raises CoercionError for invalid strings" do
        expect { coercion.call("invalid") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for strings with mixed content" do
        expect { coercion.call("3.14abc") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for alphanumeric strings" do
        expect { coercion.call("abc123") }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end
    end

    context "with numeric values" do
      it "returns floats unchanged" do
        result = coercion.call(3.14)

        expect(result).to eq(3.14)
      end

      it "converts integers to floats" do
        result = coercion.call(42)

        expect(result).to eq(42.0)
      end

      it "converts zero to float" do
        result = coercion.call(0)

        expect(result).to eq(0.0)
      end

      it "converts negative integers to floats" do
        result = coercion.call(-42)

        expect(result).to eq(-42.0)
      end

      it "handles big integers" do
        result = coercion.call(123_456_789_012_345)

        expect(result).to eq(123_456_789_012_345.0)
      end

      it "handles rational numbers" do
        result = coercion.call(Rational(22, 7))

        expect(result).to be_within(0.001).of(3.143)
      end

      it "handles complex numbers with zero imaginary part" do
        result = coercion.call(Complex(3.14, 0))

        expect(result).to eq(3.14)
      end

      it "raises CoercionError for complex numbers with non-zero imaginary part" do
        expect { coercion.call(Complex(3, 4)) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end
    end

    context "with special float values" do
      it "handles positive infinity" do
        result = coercion.call(Float::INFINITY)

        expect(result).to eq(Float::INFINITY)
      end

      it "handles negative infinity" do
        result = coercion.call(-Float::INFINITY)

        expect(result).to eq(-Float::INFINITY)
      end

      it "handles NaN" do
        result = coercion.call(Float::NAN)

        expect(result).to be_nan
      end
    end

    context "with invalid values" do
      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for arrays" do
        expect { coercion.call([1, 2, 3]) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for hashes" do
        expect { coercion.call({ value: 3.14 }) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for boolean values" do
        expect { coercion.call(true) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
        expect { coercion.call(false) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end

      it "raises CoercionError for objects" do
        expect { coercion.call(Object.new) }.to raise_error(
          CMDx::CoercionError, /could not coerce into a float/
        )
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = coercion.call("3.14", { some: "option" })

        expect(result).to eq(3.14)
      end

      it "processes numeric strings with options parameter" do
        result = coercion.call("42", { some: "option" })

        expect(result).to eq(42.0)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessRatingTask") do
        required :rating, type: :float
        optional :threshold, type: :float, default: 0.0

        def call
          context.processed_rating = rating * 2
          context.above_threshold = rating > threshold
        end
      end
    end

    it "coerces string parameters to floats" do
      result = task_class.call(rating: "4.5")

      expect(result).to be_success
      expect(result.context.processed_rating).to eq(9.0)
    end

    it "coerces integer parameters to floats" do
      result = task_class.call(rating: 4)

      expect(result).to be_success
      expect(result.context.processed_rating).to eq(8.0)
    end

    it "handles float parameters unchanged" do
      result = task_class.call(rating: 4.5)

      expect(result).to be_success
      expect(result.context.processed_rating).to eq(9.0)
    end

    it "uses default values for optional float parameters" do
      result = task_class.call(rating: 1.0)

      expect(result).to be_success
      expect(result.context.above_threshold).to be(true)
    end

    it "compares floats correctly with threshold" do
      result = task_class.call(rating: "2.5", threshold: "3.0")

      expect(result).to be_success
      expect(result.context.above_threshold).to be(false)
    end

    it "handles scientific notation in parameters" do
      result = task_class.call(rating: "1.5e1")

      expect(result).to be_success
      expect(result.context.processed_rating).to eq(30.0)
    end

    it "fails with infinity values" do
      result = task_class.call(rating: "Infinity")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a float")
    end

    it "fails with invalid float parameters" do
      result = task_class.call(rating: "invalid")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into a float")
    end
  end
end

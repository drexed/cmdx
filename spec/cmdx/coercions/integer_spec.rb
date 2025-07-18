# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Integer do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call("42")).to eq(42)
    end
  end

  describe "#call" do
    context "with string values" do
      it "converts valid integer strings" do
        result = coercion.call("123")

        expect(result).to eq(123)
      end

      it "converts negative integer strings" do
        result = coercion.call("-456")

        expect(result).to eq(-456)
      end

      it "converts zero string" do
        result = coercion.call("0")

        expect(result).to eq(0)
      end

      it "converts positive integer strings with plus sign" do
        result = coercion.call("+789")

        expect(result).to eq(789)
      end

      it "converts hexadecimal strings" do
        result = coercion.call("0x1A")

        expect(result).to eq(26)
      end

      it "converts octal strings" do
        result = coercion.call("0755")

        expect(result).to eq(493)
      end

      it "converts binary strings" do
        result = coercion.call("0b1010")

        expect(result).to eq(10)
      end

      it "raises CoercionError for invalid integer strings" do
        expect { coercion.call("abc") }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for empty strings" do
        expect { coercion.call("") }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for whitespace-only strings" do
        expect { coercion.call("   ") }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for mixed alphanumeric strings" do
        expect { coercion.call("123abc") }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for floating point strings" do
        expect { coercion.call("12.34") }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end
    end

    context "with numeric values" do
      it "converts integers unchanged" do
        result = coercion.call(42)

        expect(result).to eq(42)
      end

      it "converts negative integers unchanged" do
        result = coercion.call(-123)

        expect(result).to eq(-123)
      end

      it "converts zero unchanged" do
        result = coercion.call(0)

        expect(result).to eq(0)
      end

      it "converts floats to integers by truncation" do
        result = coercion.call(3.14)

        expect(result).to eq(3)
      end

      it "converts negative floats to integers by truncation" do
        result = coercion.call(-2.99)

        expect(result).to eq(-2)
      end

      it "converts float zero to integer zero" do
        result = coercion.call(0.0)

        expect(result).to eq(0)
      end

      it "converts very large floats" do
        result = coercion.call(1e10)

        expect(result).to eq(10_000_000_000)
      end

      it "converts BigDecimal values" do
        result = coercion.call(BigDecimal("123.45"))

        expect(result).to eq(123)
      end

      it "converts Rational values" do
        result = coercion.call(Rational(7, 2))

        expect(result).to eq(3)
      end

      it "converts Complex values with zero imaginary part" do
        result = coercion.call(Complex(42, 0))

        expect(result).to eq(42)
      end

      it "raises CoercionError for Complex values with non-zero imaginary part" do
        expect { coercion.call(Complex(3, 4)) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for infinity" do
        expect { coercion.call(Float::INFINITY) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for negative infinity" do
        expect { coercion.call(-Float::INFINITY) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for NaN" do
        expect { coercion.call(Float::NAN) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end
    end

    context "with boolean values" do
      it "raises CoercionError for true" do
        expect { coercion.call(true) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for false" do
        expect { coercion.call(false) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end
    end

    context "with nil values" do
      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end
    end

    context "with array values" do
      it "raises CoercionError for arrays" do
        expect { coercion.call([1, 2, 3]) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for empty arrays" do
        expect { coercion.call([]) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end
    end

    context "with hash values" do
      it "raises CoercionError for hashes" do
        expect { coercion.call({ a: 1 }) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "raises CoercionError for empty hashes" do
        expect { coercion.call({}) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end
    end

    context "with object values" do
      it "raises CoercionError for objects" do
        expect { coercion.call(Object.new) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end

      it "converts Time objects to timestamps" do
        time = Time.new(2023, 1, 1, 12, 0, 0)
        result = coercion.call(time)

        expect(result).to eq(time.to_i)
      end

      it "raises CoercionError for Date objects" do
        expect { coercion.call(Date.today) }.to raise_error(
          CMDx::CoercionError, /could not coerce into an integer/
        )
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = coercion.call("42", { some: "option" })

        expect(result).to eq(42)
      end

      it "processes values with options parameter" do
        result = coercion.call(3.14, { some: "option" })

        expect(result).to eq(3)
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessCountTask") do
        required :count, type: :integer
        optional :limit, type: :integer, default: 100

        def call
          context.processed_count = count * 2
          context.within_limit = count <= limit
        end
      end
    end

    it "coerces string parameters to integers" do
      result = task_class.call(count: "42")

      expect(result).to be_success
      expect(result.context.processed_count).to eq(84)
      expect(result.context.within_limit).to be true
    end

    it "coerces float parameters to integers" do
      result = task_class.call(count: 3.14)

      expect(result).to be_success
      expect(result.context.processed_count).to eq(6)
      expect(result.context.within_limit).to be true
    end

    it "handles integer parameters unchanged" do
      result = task_class.call(count: 25)

      expect(result).to be_success
      expect(result.context.processed_count).to eq(50)
      expect(result.context.within_limit).to be true
    end

    it "fails when coercion fails for boolean values" do
      result = task_class.call(count: true)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into an integer")
    end

    it "uses default values for optional integer parameters" do
      result = task_class.call(count: 50)

      expect(result).to be_success
      expect(result.context.within_limit).to be true
    end

    it "coerces optional parameters when provided" do
      result = task_class.call(count: 150, limit: "200")

      expect(result).to be_success
      expect(result.context.processed_count).to eq(300)
      expect(result.context.within_limit).to be true
    end

    it "fails when coercion fails for invalid strings" do
      result = task_class.call(count: "invalid")

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into an integer")
    end

    it "fails when coercion fails for nil values" do
      result = task_class.call(count: nil)

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into an integer")
    end

    it "fails when coercion fails for array values" do
      result = task_class.call(count: [1, 2, 3])

      expect(result).to be_failed
      expect(result.metadata[:reason]).to include("could not coerce into an integer")
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Coercions do
  describe ":integer" do
    it "coerces string to integer" do
      expect(described_class.coerce(:integer, "42")).to eq(42)
    end

    it "handles hex" do
      expect(described_class.coerce(:integer, "0xFF")).to eq(255)
    end

    it "raises on invalid input" do
      expect { described_class.coerce(:integer, "abc") }.to raise_error(CMDx::CoercionError)
    end
  end

  describe ":float" do
    it "coerces string to float" do
      expect(described_class.coerce(:float, "3.14")).to eq(3.14)
    end
  end

  describe ":string" do
    it "coerces to string" do
      expect(described_class.coerce(:string, 123)).to eq("123")
    end
  end

  describe ":boolean" do
    it "coerces truthy strings" do
      %w[true yes on 1 t y].each do |val|
        expect(described_class.coerce(:boolean, val)).to be(true)
      end
    end

    it "coerces falsy strings" do
      %w[false no off 0 f n].each do |val|
        expect(described_class.coerce(:boolean, val)).to be(false)
      end
    end

    it "raises on unknown" do
      expect { described_class.coerce(:boolean, "maybe") }.to raise_error(CMDx::CoercionError)
    end
  end

  describe ":symbol" do
    it "coerces string to symbol" do
      expect(described_class.coerce(:symbol, "hello")).to eq(:hello)
    end
  end

  describe ":array" do
    it "wraps non-arrays" do
      expect(described_class.coerce(:array, "val")).to eq(["val"])
    end

    it "parses JSON arrays" do
      expect(described_class.coerce(:array, "[1,2,3]")).to eq([1, 2, 3])
    end
  end

  describe ":hash" do
    it "parses JSON hashes" do
      expect(described_class.coerce(:hash, '{"a":1}')).to eq("a" => 1)
    end

    it "raises on non-hash" do
      expect { described_class.coerce(:hash, "not json") }.to raise_error(CMDx::CoercionError)
    end
  end

  describe ":big_decimal" do
    it "coerces to BigDecimal" do
      result = described_class.coerce(:big_decimal, "123.456")
      expect(result).to be_a(BigDecimal)
    end
  end

  describe ":date" do
    it "parses date string" do
      result = described_class.coerce(:date, "2024-01-23")
      expect(result).to eq(Date.new(2024, 1, 23))
    end
  end

  describe "fallback chain" do
    it "tries types in order" do
      result = described_class.coerce([:float, :string], "3.14")
      expect(result).to eq(3.14)
    end

    it "falls through to next type on failure" do
      result = described_class.coerce([:integer, :string], "abc")
      expect(result).to eq("abc")
    end
  end

  describe "nil passthrough" do
    it "returns nil without coercing" do
      expect(described_class.coerce(:integer, nil)).to be_nil
    end
  end
end

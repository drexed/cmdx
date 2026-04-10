# frozen_string_literal: true

RSpec.describe "Coercions" do
  describe CMDx::Coercions::Array do
    it "coerces to array" do
      expect(described_class.call([1])).to eq([1])
      expect(described_class.call("hello")).to eq(["hello"])
    end
  end

  describe CMDx::Coercions::BigDecimal do
    it "coerces to BigDecimal" do
      expect(described_class.call("1.5")).to eq(BigDecimal("1.5"))
      expect(described_class.call(1)).to eq(BigDecimal("1"))
    end
  end

  describe CMDx::Coercions::Boolean do
    it "coerces truthy values" do
      %w[true yes 1 on].each { |v| expect(described_class.call(v)).to be true }
      expect(described_class.call(true)).to be true
    end

    it "coerces falsy values" do
      %w[false no 0 off].each { |v| expect(described_class.call(v)).to be false }
      expect(described_class.call(false)).to be false
      expect(described_class.call(nil)).to be false
    end

    it "raises on unknown values" do
      expect { described_class.call("maybe") }.to raise_error(CMDx::CoercionError)
    end
  end

  describe CMDx::Coercions::Complex do
    it "coerces to Complex" do
      expect(described_class.call("3+4i")).to eq(Complex(3, 4))
    end
  end

  describe CMDx::Coercions::Date do
    it "coerces to Date" do
      expect(described_class.call("2024-01-15")).to eq(Date.new(2024, 1, 15))
    end

    it "passes through Date instances" do
      d = Date.today
      expect(described_class.call(d)).to equal(d)
    end
  end

  describe CMDx::Coercions::DateTime do
    it "coerces to DateTime" do
      expect(described_class.call("2024-01-15T10:00:00")).to be_a(DateTime)
    end
  end

  describe CMDx::Coercions::Float do
    it "coerces to Float" do
      expect(described_class.call("1.5")).to eq(1.5)
      expect(described_class.call(1)).to eq(1.0)
    end
  end

  describe CMDx::Coercions::Hash do
    it "coerces to Hash" do
      struct = Struct.new(:a).new(1)
      expect(described_class.call(struct)).to eq({ a: 1 })
    end

    it "passes through Hash instances" do
      h = { a: 1 }
      expect(described_class.call(h)).to equal(h)
    end
  end

  describe CMDx::Coercions::Integer do
    it "coerces to Integer" do
      expect(described_class.call("42")).to eq(42)
      expect(described_class.call(3.7)).to eq(3)
    end

    it "raises on non-numeric strings" do
      expect { described_class.call("abc") }.to raise_error(CMDx::CoercionError)
    end
  end

  describe CMDx::Coercions::Rational do
    it "coerces to Rational" do
      expect(described_class.call("1/3")).to eq(Rational(1, 3))
    end
  end

  describe CMDx::Coercions::String do
    it "coerces to String" do
      expect(described_class.call(42)).to eq("42")
      expect(described_class.call(:sym)).to eq("sym")
    end
  end

  describe CMDx::Coercions::Symbol do
    it "coerces to Symbol" do
      expect(described_class.call("hello")).to eq(:hello)
    end
  end

  describe CMDx::Coercions::Time do
    it "coerces to Time" do
      expect(described_class.call("2024-01-15 10:00:00")).to be_a(Time)
    end
  end
end

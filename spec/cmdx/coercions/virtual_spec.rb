# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Virtual do
  describe "#call" do
    context "with any values" do
      it "returns string value unchanged" do
        expect(described_class.call("hello")).to eq("hello")
      end

      it "returns integer value unchanged" do
        expect(described_class.call(123)).to eq(123)
      end

      it "returns float value unchanged" do
        expect(described_class.call(3.14)).to eq(3.14)
      end

      it "returns boolean true unchanged" do
        expect(described_class.call(true)).to be(true)
      end

      it "returns boolean false unchanged" do
        expect(described_class.call(false)).to be(false)
      end

      it "returns nil unchanged" do
        expect(described_class.call(nil)).to be_nil
      end

      it "returns array unchanged" do
        array = [1, 2, 3]
        expect(described_class.call(array)).to eq(array)
      end

      it "returns hash unchanged" do
        hash = { key: "value" }
        expect(described_class.call(hash)).to eq(hash)
      end

      it "returns symbol unchanged" do
        expect(described_class.call(:test)).to eq(:test)
      end

      it "returns object unchanged" do
        obj = Object.new
        expect(described_class.call(obj)).to eq(obj)
      end
    end

    context "with complex values" do
      it "returns empty string unchanged" do
        expect(described_class.call("")).to eq("")
      end

      it "returns empty array unchanged" do
        expect(described_class.call([])).to eq([])
      end

      it "returns empty hash unchanged" do
        expect(described_class.call({})).to eq({})
      end

      it "returns nested array unchanged" do
        array = [[1, 2], [3, 4]]
        expect(described_class.call(array)).to eq(array)
      end

      it "returns nested hash unchanged" do
        hash = { outer: { inner: "value" } }
        expect(described_class.call(hash)).to eq(hash)
      end
    end

    context "with numeric edge cases" do
      it "returns zero unchanged" do
        expect(described_class.call(0)).to eq(0)
      end

      it "returns negative integer unchanged" do
        expect(described_class.call(-123)).to eq(-123)
      end

      it "returns negative float unchanged" do
        expect(described_class.call(-3.14)).to eq(-3.14)
      end

      it "returns very large number unchanged" do
        large_number = 999_999_999_999_999_999_999
        expect(described_class.call(large_number)).to eq(large_number)
      end

      it "returns very small number unchanged" do
        small_number = 0.000000000000001
        expect(described_class.call(small_number)).to eq(small_number)
      end
    end

    context "with special objects" do
      it "returns Date unchanged" do
        date = Date.new(2023, 12, 25)
        expect(described_class.call(date)).to eq(date)
      end

      it "returns Time unchanged" do
        time = Time.new(2023, 12, 25, 10, 30, 45)
        expect(described_class.call(time)).to eq(time)
      end

      it "returns BigDecimal unchanged" do
        big_decimal = BigDecimal("123.45")
        expect(described_class.call(big_decimal)).to eq(big_decimal)
      end

      it "returns Rational unchanged" do
        rational = Rational(3, 4)
        expect(described_class.call(rational)).to eq(rational)
      end

      it "returns Complex unchanged" do
        complex = Complex(1, 2)
        expect(described_class.call(complex)).to eq(complex)
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        expect(described_class.call("test", { key: "value" })).to eq("test")
      end

      it "works with empty options" do
        expect(described_class.call(42, {})).to eq(42)
      end

      it "works with nil options" do
        expect(described_class.call(:symbol, nil)).to eq(:symbol)
      end

      it "works with complex options" do
        options = { format: "%Y-%m-%d", precision: 10, custom: { nested: "value" } }
        expect(described_class.call("unchanged", options)).to eq("unchanged")
      end
    end

    context "with string variations" do
      it "returns string with spaces unchanged" do
        expect(described_class.call("  hello world  ")).to eq("  hello world  ")
      end

      it "returns string with special characters unchanged" do
        expect(described_class.call("hello@world!#$%")).to eq("hello@world!#$%")
      end

      it "returns unicode string unchanged" do
        expect(described_class.call("héllo wörld")).to eq("héllo wörld")
      end

      it "returns emoji string unchanged" do
        expect(described_class.call("😀 hello 🌍")).to eq("😀 hello 🌍")
      end

      it "returns newline string unchanged" do
        expect(described_class.call("hello\nworld")).to eq("hello\nworld")
      end
    end

    context "with class and module values" do
      it "returns class unchanged" do
        expect(described_class.call(String)).to eq(String)
      end

      it "returns module unchanged" do
        expect(described_class.call(Enumerable)).to eq(Enumerable)
      end
    end

    context "with proc and lambda values" do
      it "returns proc unchanged" do
        proc_obj = proc { "test" }
        expect(described_class.call(proc_obj)).to eq(proc_obj)
      end

      it "returns lambda unchanged" do
        lambda_obj = -> { "test" }
        expect(described_class.call(lambda_obj)).to eq(lambda_obj)
      end
    end
  end
end

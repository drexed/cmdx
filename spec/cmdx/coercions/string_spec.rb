# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::String do
  describe "#call" do
    context "with string values" do
      it "returns string unchanged" do
        expect(described_class.call("hello")).to eq("hello")
      end

      it "returns empty string unchanged" do
        expect(described_class.call("")).to eq("")
      end

      it "returns string with spaces" do
        expect(described_class.call("  hello world  ")).to eq("  hello world  ")
      end

      it "returns string with special characters" do
        expect(described_class.call("hello@world!")).to eq("hello@world!")
      end
    end

    context "with numeric values" do
      it "converts integer to string" do
        expect(described_class.call(123)).to eq("123")
      end

      it "converts negative integer to string" do
        expect(described_class.call(-456)).to eq("-456")
      end

      it "converts zero to string" do
        expect(described_class.call(0)).to eq("0")
      end

      it "converts float to string" do
        expect(described_class.call(3.14)).to eq("3.14")
      end

      it "converts negative float to string" do
        expect(described_class.call(-2.5)).to eq("-2.5")
      end
    end

    context "with boolean values" do
      it "converts true to string" do
        expect(described_class.call(true)).to eq("true")
      end

      it "converts false to string" do
        expect(described_class.call(false)).to eq("false")
      end
    end

    context "with symbol values" do
      it "converts symbol to string" do
        expect(described_class.call(:test)).to eq("test")
      end

      it "converts symbol with underscores" do
        expect(described_class.call(:test_symbol)).to eq("test_symbol")
      end

      it "converts empty symbol" do
        expect(described_class.call(:"")).to eq("")
      end
    end

    context "with nil values" do
      it "converts nil to empty string" do
        expect(described_class.call(nil)).to eq("")
      end
    end

    context "with array values" do
      it "converts array to string" do
        expect(described_class.call([1, 2, 3])).to eq("[1, 2, 3]")
      end

      it "converts empty array to string" do
        expect(described_class.call([])).to eq("[]")
      end

      it "converts mixed array to string" do
        expect(described_class.call([1, "a", :b])).to eq("[1, \"a\", :b]")
      end
    end

    context "with hash values" do
      it "converts hash to string" do
        result = described_class.call({ a: 1, b: 2 })
        expect(result).to be_a(String)
        expect(result).to include("a")
        expect(result).to include("b")
      end

      it "converts empty hash to string" do
        expect(described_class.call({})).to eq("{}")
      end
    end

    context "with object values" do
      it "converts object to string" do
        obj = Object.new
        result = described_class.call(obj)
        expect(result).to be_a(String)
        expect(result).to include("Object")
      end

      it "converts class to string" do
        expect(described_class.call(String)).to eq("String")
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        expect(described_class.call("test", { key: "value" })).to eq("test")
      end

      it "works with empty options" do
        expect(described_class.call(42, {})).to eq("42")
      end

      it "works with nil options" do
        expect(described_class.call(:symbol, nil)).to eq("symbol")
      end
    end

    context "with unicode and special characters" do
      it "handles unicode characters" do
        expect(described_class.call("héllo")).to eq("héllo")
      end

      it "handles emoji" do
        expect(described_class.call("😀")).to eq("😀")
      end

      it "handles newlines and tabs" do
        expect(described_class.call("hello\nworld\t")).to eq("hello\nworld\t")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::Symbol do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is already a Symbol" do
      it "returns the symbol unchanged" do
        symbol = :hello

        result = coercion.call(symbol)

        expect(result).to be_a(Symbol)
        expect(result).to eq(:hello)
        expect(result).to be(symbol)
      end

      it "returns empty symbol unchanged" do
        symbol = :""

        result = coercion.call(symbol)

        expect(result).to be_a(Symbol)
        expect(result).to eq(:"")
        expect(result).to be(symbol)
      end

      it "returns symbol with special characters unchanged" do
        symbol = :hello_world!

        result = coercion.call(symbol)

        expect(result).to be_a(Symbol)
        expect(result).to eq(:hello_world!)
        expect(result).to be(symbol)
      end

      it "returns symbol with unicode characters unchanged" do
        symbol = :héllo_wörld_🌍

        result = coercion.call(symbol)

        expect(result).to be_a(Symbol)
        expect(result).to eq(:héllo_wörld_🌍)
        expect(result).to be(symbol)
      end
    end

    context "when value is a String" do
      it "converts string to symbol" do
        result = coercion.call("hello")

        expect(result).to be_a(Symbol)
        expect(result).to eq(:hello)
      end

      it "converts empty string to empty symbol" do
        result = coercion.call("")

        expect(result).to be_a(Symbol)
        expect(result).to eq(:"")
      end

      it "converts string with special characters to symbol" do
        result = coercion.call("hello_world!")

        expect(result).to be_a(Symbol)
        expect(result).to eq(:hello_world!)
      end

      it "converts string with spaces to symbol" do
        result = coercion.call("hello world")

        expect(result).to be_a(Symbol)
        expect(result).to eq(:"hello world")
      end

      it "converts string with unicode characters to symbol" do
        result = coercion.call("héllo wörld 🌍")

        expect(result).to be_a(Symbol)
        expect(result).to eq(:"héllo wörld 🌍")
      end

      it "converts string with newlines and tabs to symbol" do
        result = coercion.call("hello\nworld\t!")

        expect(result).to be_a(Symbol)
        expect(result).to eq(:"hello\nworld\t!")
      end

      it "converts numeric string to symbol" do
        result = coercion.call("123")

        expect(result).to be_a(Symbol)
        expect(result).to eq(:"123")
      end
    end

    context "when value has custom to_sym method" do
      it "uses the custom to_sym method" do
        custom_object = Object.new
        def custom_object.to_sym
          :custom_symbol
        end

        result = coercion.call(custom_object)

        expect(result).to be_a(Symbol)
        expect(result).to eq(:custom_symbol)
      end
    end

    context "when value is invalid" do
      it "raises CoercionError for nil" do
        expect { coercion.call(nil) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for integer" do
        expect { coercion.call(123) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for float" do
        expect { coercion.call(3.14) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for rational" do
        expect { coercion.call(Rational(3, 4)) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for complex" do
        expect { coercion.call(Complex(1, 2)) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for BigDecimal" do
        expect { coercion.call(BigDecimal("123.456")) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for boolean true" do
        expect { coercion.call(true) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for boolean false" do
        expect { coercion.call(false) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for array" do
        expect { coercion.call([1, 2, 3]) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for hash" do
        expect { coercion.call({ key: "value" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for object without to_sym method" do
        expect { coercion.call(Object.new) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for class" do
        expect { coercion.call(String) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for module" do
        expect { coercion.call(Enumerable) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for proc" do
        expect { coercion.call(proc { "hello" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for lambda" do
        expect { coercion.call(-> { "hello" }) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for method object" do
        expect { coercion.call("test".method(:upcase)) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for regex" do
        expect { coercion.call(/pattern/) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for range" do
        expect { coercion.call(1..10) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end

      it "raises CoercionError for set" do
        expect { coercion.call(Set.new([1, 2, 3])) }
          .to raise_error(CMDx::CoercionError, "could not coerce into a symbol")
      end
    end

    context "with options parameter" do
      it "ignores options and converts value normally" do
        result = coercion.call("hello", { some: "option" })

        expect(result).to be_a(Symbol)
        expect(result).to eq(:hello)
      end

      it "works with empty options hash" do
        result = coercion.call("world", {})

        expect(result).to be_a(Symbol)
        expect(result).to eq(:world)
      end
    end
  end
end

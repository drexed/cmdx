# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::String, type: :unit do
  subject(:coercion) { described_class }

  describe ".call" do
    context "when value is already a String" do
      it "returns the string unchanged" do
        string = "hello world"

        result = coercion.call(string)

        expect(result).to be_a(String)
        expect(result).to eq("hello world")
        expect(result).to be(string)
      end

      it "returns an empty string unchanged" do
        string = ""

        result = coercion.call(string)

        expect(result).to be_a(String)
        expect(result).to eq("")
        expect(result).to be(string)
      end

      it "returns string with special characters unchanged" do
        string = "hello\nworld\t!"

        result = coercion.call(string)

        expect(result).to be_a(String)
        expect(result).to eq("hello\nworld\t!")
        expect(result).to be(string)
      end

      it "returns unicode string unchanged" do
        string = "héllo wörld 🌍"

        result = coercion.call(string)

        expect(result).to be_a(String)
        expect(result).to eq("héllo wörld 🌍")
        expect(result).to be(string)
      end
    end

    context "when value is a Symbol" do
      it "converts symbol to string" do
        result = coercion.call(:hello)

        expect(result).to be_a(String)
        expect(result).to eq("hello")
      end

      it "converts symbol with underscores to string" do
        result = coercion.call(:hello_world)

        expect(result).to be_a(String)
        expect(result).to eq("hello_world")
      end

      it "converts empty symbol to string" do
        result = coercion.call(:"")

        expect(result).to be_a(String)
        expect(result).to eq("")
      end
    end

    context "when value is a numeric type" do
      it "converts integer to string" do
        result = coercion.call(123)

        expect(result).to be_a(String)
        expect(result).to eq("123")
      end

      it "converts negative integer to string" do
        result = coercion.call(-456)

        expect(result).to be_a(String)
        expect(result).to eq("-456")
      end

      it "converts zero to string" do
        result = coercion.call(0)

        expect(result).to be_a(String)
        expect(result).to eq("0")
      end

      it "converts float to string" do
        result = coercion.call(123.456)

        expect(result).to be_a(String)
        expect(result).to eq("123.456")
      end

      it "converts Rational to string" do
        result = coercion.call(Rational(3, 4))

        expect(result).to be_a(String)
        expect(result).to eq("3/4")
      end

      it "converts Complex to string" do
        result = coercion.call(Complex(3, 4))

        expect(result).to be_a(String)
        expect(result).to eq("3+4i")
      end

      it "converts BigDecimal to string" do
        result = coercion.call(BigDecimal("123.456"))

        expect(result).to be_a(String)
        expect(result).to eq("0.123456e3")
      end
    end

    context "when value is a boolean" do
      it "converts true to string" do
        result = coercion.call(true)

        expect(result).to be_a(String)
        expect(result).to eq("true")
      end

      it "converts false to string" do
        result = coercion.call(false)

        expect(result).to be_a(String)
        expect(result).to eq("false")
      end
    end

    context "when value is nil" do
      it "converts nil to empty string" do
        result = coercion.call(nil)

        expect(result).to be_a(String)
        expect(result).to eq("")
      end
    end

    context "when value is a collection" do
      it "converts array to string" do
        result = coercion.call([1, 2, 3])

        expect(result).to be_a(String)
        expect(result).to eq("[1, 2, 3]")
      end

      it "converts empty array to string" do
        result = coercion.call([])

        expect(result).to be_a(String)
        expect(result).to eq("[]")
      end

      it "converts hash to string" do
        result = coercion.call({ a: 1, b: 2 })

        expect(result).to be_a(String)
        expect(result).to eq("{a: 1, b: 2}")
      end

      it "converts empty hash to string" do
        result = coercion.call({})

        expect(result).to be_a(String)
        expect(result).to eq("{}")
      end

      it "converts set to string" do
        result = coercion.call(Set.new([1, 2, 3]))

        expect(result).to be_a(String)
        expect(result).to eq("#<Set: {1, 2, 3}>")
      end
    end

    context "when value is a special object" do
      it "converts class to string" do
        result = coercion.call(String)

        expect(result).to be_a(String)
        expect(result).to eq("String")
      end

      it "converts module to string" do
        result = coercion.call(Enumerable)

        expect(result).to be_a(String)
        expect(result).to eq("Enumerable")
      end

      it "converts regex to string" do
        result = coercion.call(/hello/)

        expect(result).to be_a(String)
        expect(result).to eq("(?-mix:hello)")
      end

      it "converts range to string" do
        result = coercion.call(1..5)

        expect(result).to be_a(String)
        expect(result).to eq("1..5")
      end

      it "converts time to string" do
        time = Time.new(2023, 12, 25, 10, 30, 45)

        result = coercion.call(time)

        expect(result).to be_a(String)
        expect(result).to include("2023-12-25")
      end

      it "converts date to string" do
        date = Date.new(2023, 12, 25)

        result = coercion.call(date)

        expect(result).to be_a(String)
        expect(result).to eq("2023-12-25")
      end
    end

    context "when value has custom to_s method" do
      it "converts object with custom to_s to string" do
        custom_object = Object.new
        def custom_object.to_s
          "custom object"
        end

        result = coercion.call(custom_object)

        expect(result).to be_a(String)
        expect(result).to eq("custom object")
      end
    end

    context "when options are provided" do
      it "ignores options parameter" do
        result = coercion.call(123, { format: :uppercase })

        expect(result).to be_a(String)
        expect(result).to eq("123")
      end

      it "works with empty options hash" do
        result = coercion.call("hello", {})

        expect(result).to be_a(String)
        expect(result).to eq("hello")
      end
    end
  end
end

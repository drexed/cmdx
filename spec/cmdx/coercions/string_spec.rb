# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions::String do
  subject(:coercion) { described_class.new }

  describe ".call" do
    it "creates instance and calls #call method" do
      expect(described_class.call(123)).to eq("123")
    end
  end

  describe "#call" do
    context "with string values" do
      it "returns strings unchanged" do
        result = coercion.call("hello world")

        expect(result).to eq("hello world")
      end

      it "returns empty strings unchanged" do
        result = coercion.call("")

        expect(result).to eq("")
      end

      it "handles strings with special characters" do
        result = coercion.call("Hello, 世界! 🌍")

        expect(result).to eq("Hello, 世界! 🌍")
      end

      it "handles multi-line strings" do
        input = "line 1\nline 2\nline 3"
        result = coercion.call(input)

        expect(result).to eq("line 1\nline 2\nline 3")
      end
    end

    context "with numeric values" do
      it "converts integers to strings" do
        result = coercion.call(123)

        expect(result).to eq("123")
      end

      it "converts negative integers to strings" do
        result = coercion.call(-456)

        expect(result).to eq("-456")
      end

      it "converts zero to string" do
        result = coercion.call(0)

        expect(result).to eq("0")
      end

      it "converts floats to strings" do
        result = coercion.call(3.14159)

        expect(result).to eq("3.14159")
      end

      it "converts negative floats to strings" do
        result = coercion.call(-2.5)

        expect(result).to eq("-2.5")
      end

      it "converts BigDecimal to strings" do
        result = coercion.call(BigDecimal("99.99"))

        expect(result).to eq("0.9999e2")
      end

      it "converts Rational to strings" do
        result = coercion.call(Rational(3, 4))

        expect(result).to eq("3/4")
      end

      it "converts Complex to strings" do
        result = coercion.call(Complex(1, 2))

        expect(result).to eq("1+2i")
      end
    end

    context "with boolean values" do
      it "converts true to string" do
        result = coercion.call(true)

        expect(result).to eq("true")
      end

      it "converts false to string" do
        result = coercion.call(false)

        expect(result).to eq("false")
      end
    end

    context "with nil values" do
      it "converts nil to empty string" do
        result = coercion.call(nil)

        expect(result).to eq("")
      end
    end

    context "with symbol values" do
      it "converts symbols to strings" do
        result = coercion.call(:symbol)

        expect(result).to eq("symbol")
      end

      it "converts symbols with special characters" do
        result = coercion.call(:"hello-world")

        expect(result).to eq("hello-world")
      end

      it "converts empty symbols to empty strings" do
        result = coercion.call(:"")

        expect(result).to eq("")
      end
    end

    context "with array values" do
      it "converts arrays to their string representation" do
        result = coercion.call([1, 2, 3])

        expect(result).to match(/\[1, 2, 3\]/)
      end

      it "converts empty arrays to string representation" do
        result = coercion.call([])

        expect(result).to eq("[]")
      end

      it "converts nested arrays to string representation" do
        result = coercion.call([[1, 2], [3, 4]])

        expect(result).to match(/\[\[1, 2\], \[3, 4\]\]/)
      end
    end

    context "with hash values" do
      it "converts hashes to their string representation" do
        result = coercion.call({ a: 1, b: 2 })

        expect(result).to eq("{a: 1, b: 2}")
      end

      it "converts empty hashes to string representation" do
        result = coercion.call({})

        expect(result).to eq("{}")
      end
    end

    context "with time values" do
      it "converts Time objects to strings" do
        time = Time.new(2023, 12, 25, 12, 0, 0)
        result = coercion.call(time)

        expect(result).to include("2023-12-25")
      end

      it "converts Date objects to strings" do
        date = Date.new(2023, 12, 25)
        result = coercion.call(date)

        expect(result).to eq("2023-12-25")
      end

      it "converts DateTime objects to strings" do
        datetime = DateTime.new(2023, 12, 25, 12, 0, 0)
        result = coercion.call(datetime)

        expect(result).to include("2023-12-25")
      end
    end

    context "with object values" do
      it "converts objects with to_s method" do
        object = Object.new
        allow(object).to receive(:to_s).and_return("custom_string")
        result = coercion.call(object)

        expect(result).to eq("custom_string")
      end

      it "converts structs to their string representation" do
        person = Struct.new(:name, :age).new("John", 30)
        result = coercion.call(person)

        expect(result).to match(/#<struct.*name="John".*age=30.*>/)
      end

      it "converts classes to their string representation" do
        result = coercion.call(String)

        expect(result).to eq("String")
      end

      it "converts modules to their string representation" do
        result = coercion.call(Enumerable)

        expect(result).to eq("Enumerable")
      end
    end

    context "with options parameter" do
      it "ignores options parameter" do
        result = coercion.call(123, { some: "option" })

        expect(result).to eq("123")
      end

      it "processes all types with options parameter" do
        result = coercion.call(:symbol, { format: "custom" })

        expect(result).to eq("symbol")
      end
    end

    context "with objects that don't respond to to_s properly" do
      it "handles objects with broken to_s methods" do
        broken_object = Object.new
        allow(broken_object).to receive(:to_s).and_raise(StandardError, "broken to_s")

        expect { coercion.call(broken_object) }.to raise_error(StandardError, "broken to_s")
      end
    end
  end

  describe "integration with tasks" do
    let(:task_class) do
      create_simple_task(name: "ProcessMessageTask") do
        required :message, type: :string
        optional :prefix, type: :string, default: "Info"

        def call
          context.formatted_message = "#{prefix}: #{message}"
        end
      end
    end

    it "coerces numeric parameters to strings" do
      result = task_class.call(message: 42)

      expect(result).to be_success
      expect(result.context.formatted_message).to eq("Info: 42")
    end

    it "coerces symbol parameters to strings" do
      result = task_class.call(message: :hello)

      expect(result).to be_success
      expect(result.context.formatted_message).to eq("Info: hello")
    end

    it "coerces boolean parameters to strings" do
      result = task_class.call(message: true, prefix: false)

      expect(result).to be_success
      expect(result.context.formatted_message).to eq("false: true")
    end

    it "coerces nil parameters to empty strings" do
      result = task_class.call(message: nil)

      expect(result).to be_success
      expect(result.context.formatted_message).to eq("Info: ")
    end

    it "handles string parameters unchanged" do
      result = task_class.call(message: "Hello World")

      expect(result).to be_success
      expect(result.context.formatted_message).to eq("Info: Hello World")
    end

    it "uses default values for optional string parameters" do
      result = task_class.call(message: "test")

      expect(result).to be_success
      expect(result.context.formatted_message).to eq("Info: test")
    end

    it "coerces array parameters to string representation" do
      result = task_class.call(message: [1, 2, 3])

      expect(result).to be_success
      expect(result.context.formatted_message).to match(/Info: \[1, 2, 3\]/)
    end

    it "coerces hash parameters to string representation" do
      result = task_class.call(message: { key: "value" })

      expect(result).to be_success
      expect(result.context.formatted_message).to eq('Info: {key: "value"}')
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Format do
  subject(:format_module) { described_class }

  describe ".to_log" do
    context "when message is a Hash" do
      it "returns the hash unchanged" do
        hash = { key: "value", another: 123 }
        result = format_module.to_log(hash)

        expect(result).to eq(hash)
        expect(result).to be(hash)
      end
    end

    context "when message responds to to_hash" do
      it "converts message using to_hash method" do
        message = instance_double("Message")
        expected_hash = { converted: "via_to_hash" }

        allow(message).to receive(:respond_to?).with(:to_hash).and_return(true)
        allow(message).to receive(:to_hash).and_return(expected_hash)

        result = format_module.to_log(message)

        expect(result).to eq(expected_hash)
      end
    end

    context "when message is not an Array and responds to to_h" do
      it "converts message using to_h method" do
        message = instance_double("Message")
        expected_hash = { converted: "via_to_h" }

        allow(message).to receive(:is_a?).with(Hash).and_return(false)
        allow(message).to receive(:respond_to?).with(:to_hash).and_return(false)
        allow(message).to receive(:is_a?).with(Array).and_return(false)
        allow(message).to receive(:respond_to?).with(:to_h).and_return(true)
        allow(message).to receive(:to_h).and_return(expected_hash)

        result = format_module.to_log(message)

        expect(result).to eq(expected_hash)
      end
    end

    context "when message is an Array" do
      it "wraps array in message key even if it responds to to_h" do
        array = [1, 2, 3]

        allow(array).to receive(:respond_to?).with(:to_hash).and_return(false)
        allow(array).to receive(:respond_to?).with(:to_h).and_return(true)

        result = format_module.to_log(array)

        expect(result).to eq({ message: array })
      end
    end

    context "when message is nil" do
      it "converts nil using to_h method" do
        message = nil

        result = format_module.to_log(message)

        expect(result).to eq({})
      end
    end

    context "when message does not respond to hash conversion methods" do
      it "wraps string in message key" do
        message = "simple string"

        result = format_module.to_log(message)

        expect(result).to eq({ message: "simple string" })
      end

      it "wraps integer in message key" do
        message = 42

        result = format_module.to_log(message)

        expect(result).to eq({ message: 42 })
      end

      it "wraps complex object in message key" do
        message = Object.new

        result = format_module.to_log(message)

        expect(result).to eq({ message: message })
      end
    end
  end

  describe ".to_str" do
    context "without custom block" do
      it "formats hash using default formatter" do
        hash = { name: "John", age: 30 }

        result = format_module.to_str(hash)

        expect(result).to eq('name="John" age=30')
      end

      it "handles string values with quotes" do
        hash = { message: 'Hello "world"' }

        result = format_module.to_str(hash)

        expect(result).to eq('message="Hello \"world\""')
      end

      it "handles symbol values" do
        hash = { status: :active, type: :user }

        result = format_module.to_str(hash)

        expect(result).to eq("status=:active type=:user")
      end

      it "handles nil values" do
        hash = { value: nil, other: "test" }

        result = format_module.to_str(hash)

        expect(result).to eq('value=nil other="test"')
      end

      it "handles numeric values" do
        hash = { count: 42, rate: 3.14 }

        result = format_module.to_str(hash)

        expect(result).to eq("count=42 rate=3.14")
      end

      it "returns empty string for empty hash" do
        result = format_module.to_str({})

        expect(result).to eq("")
      end
    end

    context "with custom block" do
      it "uses custom formatter block" do
        hash = { name: "John", age: 30 }
        custom_block = proc { |key, value| "#{key}:#{value}" }

        result = format_module.to_str(hash, &custom_block)

        expect(result).to eq("name:John age:30")
      end

      it "passes key-value pairs to custom block" do
        hash = { test: "value" }
        received_args = []
        custom_block = proc { |key, value|
          received_args << [key, value]
          "#{key}=#{value}"
        }

        format_module.to_str(hash, &custom_block)

        expect(received_args).to eq([[:test, "value"]])
      end

      it "handles complex custom formatting" do
        hash = { user_id: 123, status: "active" }
        custom_block = proc { |key, value| "[#{key.upcase}]=#{value.to_s.upcase}" }

        result = format_module.to_str(hash, &custom_block)

        expect(result).to eq("[USER_ID]=123 [STATUS]=ACTIVE")
      end
    end

    context "with different hash types" do
      it "handles hash with symbol keys" do
        hash = { symbol_key: "value" }

        result = format_module.to_str(hash)

        expect(result).to eq('symbol_key="value"')
      end

      it "handles hash with string keys" do
        hash = { "string_key" => "value" }

        result = format_module.to_str(hash)

        expect(result).to eq('string_key="value"')
      end

      it "handles hash with mixed key types" do
        hash = { :symbol => "sym_val", "string" => "str_val" }

        result = format_module.to_str(hash)

        expect(result).to include('symbol="sym_val"')
        expect(result).to include('string="str_val"')
      end
    end
  end
end

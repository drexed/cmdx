# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Format do
  subject(:format_module) { described_class }

  describe ".to_log" do
    context "when message is a CMDx object with to_h method" do
      let(:cmdx_object) { instance_double("CMDx::Context", to_h: { key: "value" }) }

      before do
        klass = instance_double(
          "Class", ancestors: [
            instance_double("Class", to_s: "CMDx::Context")
          ]
        )

        allow(cmdx_object).to receive(:class).and_return(klass)
      end

      it "returns the hash representation" do
        result = format_module.to_log(cmdx_object)

        expect(result).to eq({ key: "value" })
      end

      it "calls to_h on the object" do
        allow(cmdx_object).to receive(:to_h)

        format_module.to_log(cmdx_object)

        expect(cmdx_object).to have_received(:to_h)
      end
    end

    context "when message is a CMDx::Result object" do
      let(:result_object) { instance_double("CMDx::Result", to_h: { state: "complete", status: "success" }) }

      before do
        klass = instance_double(
          "Class", ancestors: [
            instance_double("Class", to_s: "CMDx::Result"),
            instance_double("Class", to_s: "Object")
          ]
        )

        allow(result_object).to receive(:class).and_return(klass)
      end

      it "returns the hash representation" do
        result = format_module.to_log(result_object)

        expect(result).to eq({ state: "complete", status: "success" })
      end
    end

    context "when message is a CMDx::Task object" do
      let(:task_object) { instance_double("CMDx::Task", to_h: { type: "Task", class: "TestTask" }) }

      before do
        klass = instance_double(
          "Class", ancestors: [
            instance_double("Class", to_s: "CMDx::Task"),
            instance_double("Class", to_s: "Object")
          ]
        )

        allow(task_object).to receive(:class).and_return(klass)
      end

      it "returns the hash representation" do
        result = format_module.to_log(task_object)

        expect(result).to eq({ type: "Task", class: "TestTask" })
      end
    end

    context "when message responds to to_h but is not a CMDx class" do
      let(:non_cmdx_object) { instance_double("SomeClass", to_h: { data: "test" }) }

      before do
        klass = instance_double(
          "Class", ancestors: [
            instance_double("Class", to_s: "SomeClass"),
            instance_double("Class", to_s: "Object")
          ]
        )
        allow(non_cmdx_object).to receive(:class).and_return(klass)
      end

      it "returns the original message" do
        result = format_module.to_log(non_cmdx_object)

        expect(result).to eq(non_cmdx_object)
      end

      it "does not call to_h" do
        allow(non_cmdx_object).to receive(:to_h)

        format_module.to_log(non_cmdx_object)

        expect(non_cmdx_object).not_to have_received(:to_h)
      end
    end

    context "when message does not respond to to_h" do
      let(:simple_message) { "simple string message" }

      it "returns the original message" do
        result = format_module.to_log(simple_message)

        expect(result).to eq("simple string message")
      end
    end

    context "when message is nil" do
      it "returns nil" do
        result = format_module.to_log(nil)

        expect(result).to be_nil
      end
    end

    context "when message is a number" do
      it "returns the number" do
        result = format_module.to_log(42)

        expect(result).to eq(42)
      end
    end

    context "when message is an array" do
      let(:array_message) { [1, 2, 3] }

      it "returns the array" do
        result = format_module.to_log(array_message)

        expect(result).to eq([1, 2, 3])
      end
    end

    context "when message is a plain hash" do
      let(:hash_message) { { key: "value" } }

      before do
        klass = instance_double(
          "Class", ancestors: [
            instance_double("Class", to_s: "Hash"),
            instance_double("Class", to_s: "Object")
          ]
        )

        allow(hash_message).to receive(:class).and_return(klass)
      end

      it "returns the hash" do
        result = format_module.to_log(hash_message)

        expect(result).to eq({ key: "value" })
      end
    end
  end

  describe ".to_str" do
    let(:hash) { { name: "test", value: 42, flag: true } }

    context "without a custom block" do
      it "uses the default formatter" do
        result = format_module.to_str(hash)

        expect(result).to eq('name="test" value=42 flag=true')
      end

      it "formats values using inspect" do
        hash_with_string = { message: "hello world", count: 0 }

        result = format_module.to_str(hash_with_string)

        expect(result).to eq('message="hello world" count=0')
      end

      it "handles nil values" do
        hash_with_nil = { result: nil, status: "ok" }

        result = format_module.to_str(hash_with_nil)

        expect(result).to eq('result=nil status="ok"')
      end

      it "handles symbol values" do
        hash_with_symbol = { type: :test, state: :active }

        result = format_module.to_str(hash_with_symbol)

        expect(result).to eq("type=:test state=:active")
      end

      it "handles array values" do
        hash_with_array = { tags: %w[ruby testing], count: 2 }

        result = format_module.to_str(hash_with_array)

        expect(result).to eq('tags=["ruby", "testing"] count=2')
      end
    end

    context "with a custom block" do
      it "uses the custom formatter" do
        result = format_module.to_str(hash) { |k, v| "#{k.upcase}:#{v}" }

        expect(result).to eq("NAME:test VALUE:42 FLAG:true")
      end

      it "allows complex custom formatting" do
        result = format_module.to_str(hash) do |key, value|
          case value
          when String
            "[STR] #{key}=#{value}"
          when Integer
            "[INT] #{key}=#{value}"
          when TrueClass, FalseClass
            "[BOOL] #{key}=#{value}"
          else
            "[OTHER] #{key}=#{value}"
          end
        end

        expect(result).to eq("[STR] name=test [INT] value=42 [BOOL] flag=true")
      end

      it "handles blocks that return nil" do
        result = format_module.to_str(hash) { |_k, _v| nil }

        expect(result).to eq("  ")
      end

      it "handles blocks that return empty string" do
        result = format_module.to_str(hash) { |_k, _v| "" }

        expect(result).to eq("  ")
      end
    end

    context "when hash is empty" do
      let(:empty_hash) { {} }

      it "returns empty string" do
        result = format_module.to_str(empty_hash)

        expect(result).to eq("")
      end

      it "returns empty string with custom block" do
        result = format_module.to_str(empty_hash) { |k, v| "#{k}:#{v}" }

        expect(result).to eq("")
      end
    end

    context "when hash has one element" do
      let(:single_hash) { { key: "value" } }

      it "formats single element without spaces" do
        result = format_module.to_str(single_hash)

        expect(result).to eq('key="value"')
      end
    end

    context "when hash values contain special characters" do
      let(:special_hash) { { path: "/tmp/file name.txt", regex: /\w+/ } }

      it "handles special characters correctly" do
        result = format_module.to_str(special_hash)

        expect(result).to eq('path="/tmp/file name.txt" regex=/\w+/')
      end
    end

    context "when hash has nested structures" do
      let(:nested_hash) { { config: { timeout: 30, retries: 3 }, enabled: true } }

      it "formats nested structures" do
        result = format_module.to_str(nested_hash)

        expect(result).to eq("config={timeout: 30, retries: 3} enabled=true")
      end
    end
  end
end

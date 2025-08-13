# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Utils::Format, type: :unit do
  subject(:format_module) { described_class }

  describe ".to_log" do
    context "when message is a CMDx object with to_h method" do
      let(:cmdx_context) { CMDx::Context.new(user_id: 123, name: "test") }
      let(:task_class) do
        Class.new(CMDx::Task) do
          def work
            # no-op
          end
        end
      end
      let(:task) { task_class.new }

      it "returns the hash representation of CMDx::Context" do
        result = format_module.to_log(cmdx_context)

        expect(result).to eq({ user_id: 123, name: "test" })
      end

      it "returns the hash representation of CMDx::Task" do
        result = format_module.to_log(task)

        expect(result).to be_a(Hash)
        expect(result).to include(:class, :index, :chain_id, :type, :tags, :id)
      end

      it "returns the hash representation of CMDx::Chain" do
        chain = CMDx::Chain.new

        result = format_module.to_log(chain)

        expect(result).to be_a(Hash)
        expect(result).to include(:id, :results)
      end

      it "returns the hash representation of CMDx::Result" do
        task = task_class.new
        result_obj = CMDx::Result.new(task)

        result = format_module.to_log(result_obj)

        expect(result).to be_a(Hash)
        expect(result).to include(:state, :status, :outcome, :metadata)
      end

      it "returns the hash representation of CMDx::Errors" do
        errors = CMDx::Errors.new
        errors.add(:name, "can't be blank")

        result = format_module.to_log(errors)

        expect(result).to eq({ name: ["can't be blank"] })
      end
    end

    context "when message responds to to_h but is not a CMDx object" do
      let(:non_cmdx_object) do
        Class.new do
          def to_h
            { key: "value" }
          end

          def class
            Class.new do
              def ancestors
                [Object, BasicObject]
              end
            end.new
          end
        end.new
      end

      it "returns the original message unchanged" do
        result = format_module.to_log(non_cmdx_object)

        expect(result).to eq(non_cmdx_object)
      end
    end

    context "when message does not respond to to_h" do
      it "returns string message unchanged" do
        message = "Simple log message"

        result = format_module.to_log(message)

        expect(result).to eq("Simple log message")
      end

      it "returns integer message unchanged" do
        message = 42

        result = format_module.to_log(message)

        expect(result).to eq(42)
      end

      it "returns array message unchanged" do
        message = [1, 2, 3]

        result = format_module.to_log(message)

        expect(result).to eq([1, 2, 3])
      end

      it "returns hash message unchanged" do
        message = { key: "value" }

        result = format_module.to_log(message)

        expect(result).to eq({ key: "value" })
      end

      it "returns nil message unchanged" do
        result = format_module.to_log(nil)

        expect(result).to be_nil
      end
    end

    context "when message responds to to_h but ancestors check returns false" do
      let(:object_with_to_h) do
        obj = Object.new
        def obj.to_h
          { custom: "hash" }
        end
        obj
      end

      it "returns the original message unchanged" do
        result = format_module.to_log(object_with_to_h)

        expect(result).to eq(object_with_to_h)
      end
    end
  end

  describe ".to_str" do
    context "when using default formatter" do
      let(:hash) { { name: "John", age: 30, active: true } }

      it "formats hash using default key=value.inspect format" do
        result = format_module.to_str(hash)

        expect(result).to eq('name="John" age=30 active=true')
      end

      it "handles empty hash" do
        result = format_module.to_str({})

        expect(result).to eq("")
      end

      it "handles hash with symbol keys" do
        hash = { user_id: 123, email: "test@example.com" }

        result = format_module.to_str(hash)

        expect(result).to eq('user_id=123 email="test@example.com"')
      end

      it "handles hash with string keys" do
        hash = { "name" => "Alice", "role" => "admin" }

        result = format_module.to_str(hash)

        expect(result).to eq('name="Alice" role="admin"')
      end

      it "handles hash with mixed value types" do
        hash = { id: 1, name: "Test", data: [1, 2, 3], meta: { nested: true } }

        result = format_module.to_str(hash)

        expect(result).to eq('id=1 name="Test" data=[1, 2, 3] meta={nested: true}')
      end

      it "handles hash with nil values" do
        hash = { name: "John", email: nil, age: 25 }

        result = format_module.to_str(hash)

        expect(result).to eq('name="John" email=nil age=25')
      end
    end

    context "when using custom formatter block" do
      let(:hash) { { name: "John", age: 30, city: "NYC" } }

      it "uses the provided block for formatting" do
        result = format_module.to_str(hash) { |key, value| "#{key}: #{value}" }

        expect(result).to eq("name: John age: 30 city: NYC")
      end

      it "allows custom separator in block" do
        result = format_module.to_str(hash) { |key, value| "#{key}=#{value}" }

        expect(result).to eq("name=John age=30 city=NYC")
      end

      it "handles complex formatting logic in block" do
        result = format_module.to_str(hash) do |key, value|
          case key
          when :name then "USER: #{value.upcase}"
          when :age then "AGE: #{value} years"
          else "#{key.upcase}: #{value}"
          end
        end

        expect(result).to eq("USER: JOHN AGE: 30 years CITY: NYC")
      end

      it "handles block that returns nil" do
        result = format_module.to_str(hash) { |_key, _value| nil }

        expect(result).to eq("  ")
      end

      it "handles block that returns empty string" do
        result = format_module.to_str(hash) { |_key, _value| "" }

        expect(result).to eq("  ")
      end
    end

    context "with edge cases" do
      it "handles hash with special characters in values" do
        hash = { message: "Hello\nWorld", path: "/tmp/test file.txt" }

        result = format_module.to_str(hash)

        expect(result).to eq('message="Hello\nWorld" path="/tmp/test file.txt"')
      end

      it "handles hash with unicode characters" do
        hash = { name: "José", emoji: "🚀", chinese: "测试" }

        result = format_module.to_str(hash)

        expect(result).to eq('name="José" emoji="🚀" chinese="测试"')
      end

      it "handles large hash efficiently" do
        large_hash = (1..100).to_h { |i| ["key#{i}", "value#{i}"] }

        expect { format_module.to_str(large_hash) }.not_to raise_error
      end
    end
  end

  describe "FORMATTER constant" do
    it "is private" do
      expect { described_class::FORMATTER }.to raise_error(NameError)
    end

    it "is frozen" do
      formatter = described_class.send(:const_get, :FORMATTER)

      expect(formatter).to be_frozen
    end

    it "formats key-value pairs correctly" do
      formatter = described_class.send(:const_get, :FORMATTER)

      result = formatter.call(:name, "John")

      expect(result).to eq('name="John"')
    end

    it "handles different value types" do
      formatter = described_class.send(:const_get, :FORMATTER)

      expect(formatter.call(:id, 123)).to eq("id=123")
      expect(formatter.call(:active, true)).to eq("active=true")
      expect(formatter.call(:data, nil)).to eq("data=nil")
      expect(formatter.call(:items, [1, 2])).to eq("items=[1, 2]")
    end
  end
end

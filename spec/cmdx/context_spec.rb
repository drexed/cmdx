# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Context do
  describe ".build" do
    context "with no arguments" do
      it "creates empty context" do
        context = described_class.build

        expect(context).to be_a(described_class)
        expect(context.to_h).to eq({})
      end
    end

    context "with hash input" do
      it "creates context from hash" do
        context = described_class.build(name: "John", age: 30)

        expect(context).to be_a(described_class)
        expect(context.name).to eq("John")
        expect(context.age).to eq(30)
        expect(context.to_h).to eq({ name: "John", age: 30 })
      end

      it "creates context from string keyed hash" do
        context = described_class.build("name" => "Jane", "city" => "NYC")

        expect(context).to be_a(described_class)
        expect(context.name).to eq("Jane")
        expect(context.city).to eq("NYC")
        expect(context.to_h).to eq({ name: "Jane", city: "NYC" })
      end

      it "creates context from mixed key types" do
        context = described_class.build(name: "John", "age" => 30)

        expect(context).to be_a(described_class)
        expect(context.name).to eq("John")
        expect(context.age).to eq(30)
      end
    end

    context "with existing Context input" do
      let(:existing_context) { described_class.new(user_id: 123, role: "admin") }

      it "returns same context when not frozen" do
        result = described_class.build(existing_context)

        expect(result).to be(existing_context)
        expect(result.user_id).to eq(123)
        expect(result.role).to eq("admin")
      end

      it "creates new context when frozen" do
        existing_context.freeze
        result = described_class.build(existing_context)

        expect(result).to be_a(described_class)
        expect(result).not_to be(existing_context)
        expect(result.user_id).to eq(123)
        expect(result.role).to eq("admin")
        expect(result.to_h).to eq(existing_context.to_h)
      end
    end

    context "with hash-like objects" do
      it "creates context from OpenStruct" do
        open_struct = OpenStruct.new(status: "active", priority: "high")
        context = described_class.build(open_struct)

        expect(context).to be_a(described_class)
        expect(context.status).to eq("active")
        expect(context.priority).to eq("high")
      end

      it "creates context from object with to_h method" do
        hash_like_object = double("HashLike")
        allow(hash_like_object).to receive(:to_h).and_return({ task_id: "abc123", completed: true })

        context = described_class.build(hash_like_object)

        expect(context).to be_a(described_class)
        expect(context.task_id).to eq("abc123")
        expect(context.completed).to be(true)
      end
    end

    context "with invalid input" do
      it "raises ArgumentError when input doesn't respond to to_h" do
        invalid_input = "not a hash"

        expect { described_class.build(invalid_input) }.to raise_error(
          ArgumentError,
          "must be respond to `to_h`"
        )
      end

      it "raises ArgumentError with numeric input" do
        expect { described_class.build(42) }.to raise_error(
          ArgumentError,
          "must be respond to `to_h`"
        )
      end

      it "raises TypeError with array input" do
        expect { described_class.build([1, 2, 3]) }.to raise_error(
          TypeError,
          "wrong element type Integer at 0 (expected array)"
        )
      end
    end
  end
end

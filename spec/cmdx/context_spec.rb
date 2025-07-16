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

  describe "LazyStruct inheritance" do
    subject(:context) { described_class.new(name: "John", age: 30, city: "NYC") }

    it "provides hash-like access" do
      expect(context[:name]).to eq("John")
      expect(context["age"]).to eq(30)
      expect(context[:city]).to eq("NYC")
    end

    it "provides method-like access" do
      expect(context.name).to eq("John")
      expect(context.age).to eq(30)
      expect(context.city).to eq("NYC")
    end

    it "supports assignment" do
      context.role = "admin"
      context[:status] = "active"

      expect(context.role).to eq("admin")
      expect(context.status).to eq("active")
    end

    it "supports merge! for bulk updates" do
      context.merge!(department: "Engineering", level: "Senior")

      expect(context.department).to eq("Engineering")
      expect(context.level).to eq("Senior")
    end

    it "supports dig for nested access" do
      context.merge!(user: { profile: { email: "john@example.com" } }) # rubocop:disable Performance/RedundantMerge

      expect(context.dig(:user, :profile, :email)).to eq("john@example.com")
    end

    it "converts to hash with symbolized keys" do
      expect(context.to_h).to eq(
        {
          name: "John",
          age: 30,
          city: "NYC"
        }
      )
    end

    it "provides meaningful inspect output" do
      expect(context.inspect).to match(/#<CMDx::Context.*:name="John".*:age=30.*:city="NYC".*>/)
    end
  end

  describe "real-world usage patterns" do
    it "builds context for task execution" do
      params = { user_id: 42, action: "create", resource: "post" }
      context = described_class.build(params)

      # Simulate task adding execution metadata
      context.merge!( # rubocop:disable Performance/RedundantMerge
        started_at: Time.now,
        executed_by: "ProcessPostTask"
      )

      expect(context.user_id).to eq(42)
      expect(context.action).to eq("create")
      expect(context.resource).to eq("post")
      expect(context.executed_by).to eq("ProcessPostTask")
      expect(context).to respond_to(:started_at)
    end

    it "preserves existing context in task chains" do
      initial_context = described_class.build(
        request_id: "req-123",
        user_id: 456,
        metadata: { source: "api" }
      )

      # Simulate passing through multiple tasks
      updated_context = described_class.build(initial_context)
      updated_context.merge!( # rubocop:disable Performance/RedundantMerge
        step_1_completed: true,
        step_2_result: "processed"
      )

      expect(updated_context).to be(initial_context)
      expect(updated_context.request_id).to eq("req-123")
      expect(updated_context.step_1_completed).to be(true)
      expect(updated_context.step_2_result).to eq("processed")
    end

    it "handles frozen context gracefully" do
      frozen_context = described_class.build(config: "production", readonly: true)
      frozen_context.freeze

      new_context = described_class.build(frozen_context)
      new_context.runtime_info = "added later"

      expect(new_context).not_to be(frozen_context)
      expect(new_context.config).to eq("production")
      expect(new_context.readonly).to be(true)
      expect(new_context.runtime_info).to eq("added later")
    end
  end

  describe "edge cases" do
    it "handles empty hash" do
      context = described_class.build({})

      expect(context).to be_a(described_class)
      expect(context.to_h).to eq({})
    end

    it "handles nested hash structures" do
      nested_data = {
        user: { id: 1, profile: { name: "Test User" } },
        settings: { theme: "dark", notifications: true }
      }
      context = described_class.build(nested_data)

      expect(context.user).to eq({ id: 1, profile: { name: "Test User" } })
      expect(context.settings).to eq({ theme: "dark", notifications: true })
      expect(context.dig(:user, :profile, :name)).to eq("Test User")
    end

    it "normalizes keys consistently" do
      context = described_class.build("string_key" => "value1", symbol_key: "value2")

      expect(context[:string_key]).to eq("value1")
      expect(context.string_key).to eq("value1")
      expect(context[:symbol_key]).to eq("value2")
      expect(context.symbol_key).to eq("value2")
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Context do
  describe ".build" do
    context "when given a hash" do
      it "creates a new Context instance" do
        context = described_class.build(name: "John", age: 30)

        expect(context).to be_a(described_class)
        expect(context.name).to eq("John")
        expect(context.age).to eq(30)
      end

      it "handles empty hash input" do
        context = described_class.build({})

        expect(context).to be_a(described_class)
        expect(context.to_h).to eq({})
      end

      it "preserves hash key types" do
        input = { "string_key" => "value1", :symbol_key => "value2" }
        context = described_class.build(input)

        expect(context["string_key"]).to eq("value1")
        expect(context[:symbol_key]).to eq("value2")
      end

      it "handles nested hash structures" do
        input = {
          user: { name: "John", age: 30 },
          settings: { theme: "dark", notifications: true }
        }
        context = described_class.build(input)

        expect(context.user).to eq({ name: "John", age: 30 })
        expect(context.settings).to eq({ theme: "dark", notifications: true })
        expect(context.dig(:user, :name)).to eq("John")
      end

      it "handles complex nested data structures" do
        input = {
          data: [1, 2, 3],
          metadata: {
            created_at: Time.new(2023, 1, 1),
            tags: %w[urgent customer]
          }
        }
        context = described_class.build(input)

        expect(context.data).to eq([1, 2, 3])
        expect(context.metadata[:created_at]).to eq(Time.new(2023, 1, 1))
        expect(context.metadata[:tags]).to eq(%w[urgent customer])
      end
    end

    context "when given no arguments" do
      it "creates an empty Context instance" do
        context = described_class.build

        expect(context).to be_a(described_class)
        expect(context.to_h).to eq({})
      end

      it "allows subsequent attribute assignment" do
        context = described_class.build
        context.name = "Test"
        context[:value] = 42

        expect(context.name).to eq("Test")
        expect(context[:value]).to eq(42)
      end
    end

    context "when given an unfrozen Context instance" do
      let(:original_context) { described_class.new(name: "Original", data: "test") }

      it "returns the same instance without creating a new one" do
        result = described_class.build(original_context)

        expect(result).to be(original_context)
        expect(result.object_id).to eq(original_context.object_id)
      end

      it "preserves all existing data" do
        result = described_class.build(original_context)

        expect(result.name).to eq("Original")
        expect(result.data).to eq("test")
      end

      it "allows modifications to the returned instance" do
        result = described_class.build(original_context)
        result.new_attribute = "added"

        expect(result.new_attribute).to eq("added")
        expect(original_context.new_attribute).to eq("added")
      end
    end

    context "when given a frozen Context instance" do
      let(:frozen_context) do
        context = described_class.new(name: "Frozen", data: "immutable")
        context.freeze
      end

      it "creates a new Context instance with frozen behavior" do
        expect { described_class.build(frozen_context) }.not_to raise_error
      end
    end

    context "when given an object with to_h method" do
      let(:hash_like_object) do
        object = Object.new
        def object.to_h
          { converted: true, method: "to_h", data: [1, 2, 3] }
        end
        object
      end

      it "converts object using to_h method" do
        context = described_class.build(hash_like_object)

        expect(context).to be_a(described_class)
        expect(context.converted).to be(true)
        expect(context[:method]).to eq("to_h") # Use hash-style access to avoid conflict with Object#method
        expect(context.data).to eq([1, 2, 3])
      end

      it "handles objects with empty to_h result" do
        empty_object = Object.new
        def empty_object.to_h
          {}
        end

        context = described_class.build(empty_object)

        expect(context).to be_a(described_class)
        expect(context.to_h).to eq({})
      end
    end

    context "when given nil" do
      it "creates an empty Context instance" do
        context = described_class.build(nil)

        expect(context).to be_a(described_class)
        expect(context.to_h).to eq({})
      end
    end

    context "when testing optimization behavior" do
      it "avoids object creation for reusable contexts" do
        original = described_class.new(data: "test")
        reused = described_class.build(original)

        expect(reused).to be(original)
      end

      it "handles frozen input without errors" do
        frozen_original = described_class.new(data: "test")
        frozen_original.freeze

        expect { described_class.build(frozen_original) }.not_to raise_error
      end

      it "handles multiple build calls on same unfrozen context" do
        original = described_class.new(counter: 0)

        first_build = described_class.build(original)
        second_build = described_class.build(original)

        expect(first_build).to be(original)
        expect(second_build).to be(original)
        expect(first_build).to be(second_build)
      end
    end
  end

  describe "inheritance from LazyStruct" do
    let(:context) { described_class.build(name: "Test", age: 25) }

    it "inherits LazyStruct functionality" do
      expect(context).to respond_to(:name)
      expect(context).to respond_to(:age)
      expect(context).to respond_to(:[])
      expect(context).to respond_to(:[]=)
    end

    it "supports method-style attribute access" do
      expect(context.name).to eq("Test")
      expect(context.age).to eq(25)
    end

    it "supports hash-style attribute access" do
      expect(context[:name]).to eq("Test")
      expect(context["age"]).to eq(25)
    end

    it "supports dynamic attribute assignment" do
      context.new_attr = "dynamic"
      context[:hash_attr] = "hash-style"

      expect(context.new_attr).to eq("dynamic")
      expect(context[:hash_attr]).to eq("hash-style")
    end

    it "supports merge operations" do
      context.merge!(status: "complete", processed: true)

      expect(context.status).to eq("complete")
      expect(context.processed).to be(true)
    end

    it "supports dig operations on nested data" do
      context.metadata = { user: { id: 123, name: "John" } }

      expect(context.dig(:metadata, :user, :id)).to eq(123)
      expect(context.dig(:metadata, :user, :name)).to eq("John")
    end
  end

  describe "data manipulation" do
    let(:context) { described_class.build }

    it "allows building up context data incrementally" do
      context.step1_complete = true
      context.step1_data = { result: "success" }

      context.step2_complete = true
      context.step2_data = { processed_items: 5 }

      expect(context.step1_complete).to be(true)
      expect(context.step1_data).to eq({ result: "success" })
      expect(context.step2_complete).to be(true)
      expect(context.step2_data).to eq({ processed_items: 5 })
    end

    it "handles complex data assignment patterns" do
      context.user = { id: 1, name: "Alice" }
      context.settings = { theme: "dark" }
      context.merge!(status: "active", last_login: Time.new(2023, 1, 1))

      expect(context.user[:id]).to eq(1)
      expect(context.settings[:theme]).to eq("dark")
      expect(context.status).to eq("active")
      expect(context.last_login).to eq(Time.new(2023, 1, 1))
    end

    it "supports overwriting existing attributes" do
      context.value = "original"
      expect(context.value).to eq("original")

      context.value = "updated"
      expect(context.value).to eq("updated")

      context[:value] = "hash-updated"
      expect(context.value).to eq("hash-updated")
    end
  end

  describe "integration scenarios" do
    context "when simulating task parameter passing" do
      it "handles typical task input parameters" do
        input_params = {
          order_id: 123,
          customer_email: "customer@example.com",
          priority: "high",
          notify_customer: true
        }
        context = described_class.build(input_params)

        expect(context.order_id).to eq(123)
        expect(context.customer_email).to eq("customer@example.com")
        expect(context.priority).to eq("high")
        expect(context.notify_customer).to be(true)
      end

      it "simulates data accumulation during task execution" do
        context = described_class.build(order_id: 123)

        # Simulate first task
        context.order = { id: 123, status: "pending" }
        context.validation_passed = true

        # Simulate second task
        context.payment_result = { success: true, transaction_id: "txn_456" }
        context.payment_processed = true

        # Simulate third task
        context.inventory_updated = true
        context.confirmation_sent = true

        expect(context.order_id).to eq(123)
        expect(context.order[:status]).to eq("pending")
        expect(context.validation_passed).to be(true)
        expect(context.payment_result[:success]).to be(true)
        expect(context.payment_processed).to be(true)
        expect(context.inventory_updated).to be(true)
        expect(context.confirmation_sent).to be(true)
      end
    end

    context "when handling context passing between operations" do
      it "maintains data integrity across multiple operations" do
        # Initial context creation
        initial_data = { user_id: 456, action: "update_profile" }
        context = described_class.build(initial_data)

        # First operation adds data
        context.user = { id: 456, name: "Bob", email: "bob@example.com" }
        context.operation_1_complete = true

        # Build from existing context (should reuse)
        context2 = described_class.build(context)
        expect(context2).to be(context)

        # Second operation modifies existing context
        context2.user_updated = true
        context2.audit_log = [{ action: "profile_updated", timestamp: Time.new(2023, 1, 1) }]

        # Verify all data is accessible
        expect(context.user_id).to eq(456)
        expect(context.action).to eq("update_profile")
        expect(context.user[:name]).to eq("Bob")
        expect(context.operation_1_complete).to be(true)
        expect(context.user_updated).to be(true)
        expect(context.audit_log.first[:action]).to eq("profile_updated")
      end
    end

    context "when working with frozen contexts" do
      it "handles frozen context input without errors" do
        # Create and freeze initial context
        original_data = { read_only: true, config: { env: "production" } }
        frozen_context = described_class.build(original_data)
        frozen_context.freeze

        # Building from frozen context should not raise errors
        expect { described_class.build(frozen_context) }.not_to raise_error
        expect(frozen_context).to be_frozen
      end
    end

    context "when handling various input formats" do
      it "handles ActionController::Parameters-like objects" do
        # Simulate Rails params object
        params_like = Object.new
        def params_like.to_h
          {
            "user" => { "name" => "John", "email" => "john@example.com" },
            "settings" => { "notifications" => "true" }
          }
        end

        context = described_class.build(params_like)

        expect(context).to be_a(described_class)
        expect(context.user).to eq({ "name" => "John", "email" => "john@example.com" })
        expect(context.settings).to eq({ "notifications" => "true" })
      end

      it "handles mixed symbol and string keys in hashes" do
        mixed_input = {
          :symbol_key => "symbol_value",
          "string_key" => "string_value"
        }
        context = described_class.build(mixed_input)

        expect(context[:symbol_key]).to eq("symbol_value")
        expect(context["string_key"]).to eq("string_value")
      end
    end
  end

  describe "edge cases and error handling" do
    it "handles deeply nested hash structures" do
      deep_structure = {
        level1: {
          level2: {
            level3: {
              level4: {
                value: "deep_value"
              }
            }
          }
        }
      }
      context = described_class.build(deep_structure)

      expect(context.dig(:level1, :level2, :level3, :level4, :value)).to eq("deep_value")
    end

    it "handles arrays in context data" do
      array_data = {
        items: [1, 2, 3],
        users: [
          { name: "Alice", id: 1 },
          { name: "Bob", id: 2 }
        ]
      }
      context = described_class.build(array_data)

      expect(context.items).to eq([1, 2, 3])
      expect(context.users.first[:name]).to eq("Alice")
      expect(context.users.last[:id]).to eq(2)
    end

    it "preserves object references" do
      shared_object = { shared: true }
      input = {
        ref1: shared_object,
        ref2: shared_object
      }
      context = described_class.build(input)

      expect(context.ref1).to be(context.ref2)
      expect(context.ref1[:shared]).to be(true)
    end

    it "handles context with no initial data but subsequent assignments" do
      context = described_class.build

      expect(context.to_h).to eq({})

      context.dynamic_attr = "added later"
      context[:workflow_data] = { count: 5 }

      expect(context.dynamic_attr).to eq("added later")
      expect(context.workflow_data[:count]).to eq(5)
    end
  end
end

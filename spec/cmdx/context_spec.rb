# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Context, type: :unit do
  subject(:context) { described_class.new(initial_data) }

  let(:initial_data) { { name: "John", age: 30 } }

  describe "#initialize" do
    context "when given a hash" do
      let(:initial_data) { { name: "Alice", age: 25 } }

      it "converts keys to symbols and stores the data" do
        expect(context.table).to eq(name: "Alice", age: 25)
      end
    end

    context "when given an object that responds to to_hash" do
      let(:initial_data) do
        object = Object.new
        def object.to_hash
          { "city" => "NYC", "country" => "USA" }
        end
        object
      end

      it "converts to hash and symbolizes keys" do
        expect(context.table).to eq(city: "NYC", country: "USA")
      end
    end

    context "when given an object that responds to to_h" do
      let(:initial_data) do
        object = Object.new
        def object.to_h
          { "score" => 100, "level" => 5 }
        end
        object
      end

      it "converts to hash and symbolizes keys" do
        expect(context.table).to eq(score: 100, level: 5)
      end
    end

    context "when given an object that responds to neither to_h nor to_hash" do
      let(:initial_data) { "invalid" }

      it "raises ArgumentError" do
        expect { context }.to raise_error(ArgumentError, "must respond to `to_h` or `to_hash`")
      end
    end

    context "when given string keys" do
      let(:initial_data) { { "name" => "Bob", "active" => true } }

      it "converts string keys to symbols" do
        expect(context.table).to eq(name: "Bob", active: true)
      end
    end

    context "when given no arguments" do
      subject(:context) { described_class.new }

      it "creates empty context" do
        expect(context.table).to eq({})
      end
    end
  end

  describe ".build" do
    context "when given a Context instance that is not frozen" do
      let(:existing_context) { described_class.new(name: "test") }

      it "returns the same instance" do
        result = described_class.build(existing_context)

        expect(result).to be(existing_context)
      end
    end

    context "when given a frozen Context instance" do
      let(:frozen_context) { described_class.new(name: "test").freeze }

      it "creates a new Context instance" do
        result = described_class.build(frozen_context)

        expect(result).not_to be(frozen_context)
        expect(result.table).to eq(name: "test")
      end
    end

    context "when given an object that responds to context" do
      let(:object_with_context) do
        object = Object.new
        def object.context
          { user_id: 123 }
        end
        object
      end

      it "recursively builds from the context method result" do
        result = described_class.build(object_with_context)

        expect(result).to be_a(described_class)
        expect(result.table).to eq(user_id: 123)
      end
    end

    context "when given a hash" do
      let(:hash_data) { { role: "admin", permissions: %w[read write] } }

      it "creates new Context instance" do
        result = described_class.build(hash_data)

        expect(result).to be_a(described_class)
        expect(result.table).to eq(role: "admin", permissions: %w[read write])
      end
    end

    context "when given nil" do
      it "creates empty Context instance" do
        result = described_class.build(nil)

        expect(result).to be_a(described_class)
        expect(result.table).to eq({})
      end
    end
  end

  describe "#[]" do
    it "retrieves value by symbol key" do
      expect(context[:name]).to eq("John")
    end

    it "retrieves value by string key converted to symbol" do
      expect(context["name"]).to eq("John")
    end

    it "returns nil for non-existent key" do
      expect(context[:missing]).to be_nil
    end
  end

  describe "#store and #[]=" do
    it "stores value with symbol key" do
      context.store(:email, "john@example.com")

      expect(context[:email]).to eq("john@example.com")
    end

    it "stores value with string key converted to symbol" do
      context["phone"] = "555-1234"

      expect(context[:phone]).to eq("555-1234")
    end

    it "overwrites existing value" do
      context[:age] = 35

      expect(context[:age]).to eq(35)
    end
  end

  describe "#fetch" do
    it "retrieves existing value" do
      expect(context.fetch(:name)).to eq("John")
    end

    it "retrieves value with string key converted to symbol" do
      expect(context.fetch("age")).to eq(30)
    end

    it "returns default value for missing key" do
      expect(context.fetch(:missing, "default")).to eq("default")
    end

    it "executes block for missing key" do
      result = context.fetch(:missing) { 1 + 1 }

      expect(result).to eq(2)
    end

    it "raises KeyError for missing key without default" do
      expect { context.fetch(:missing) }.to raise_error(KeyError)
    end
  end

  describe "#fetch_or_store" do
    it "returns existing value when key exists" do
      result = context.fetch_or_store(:name, "Default")

      expect(result).to eq("John")
      expect(context.table).to include(name: "John")
    end

    it "stores and returns default value when key does not exist" do
      result = context.fetch_or_store(:email, "john@example.com")

      expect(result).to eq("john@example.com")
      expect(context.table).to include(email: "john@example.com")
    end

    it "converts string key to symbol" do
      result = context.fetch_or_store("phone", "555-1234")

      expect(result).to eq("555-1234")
      expect(context.table).to include(phone: "555-1234")
    end

    it "returns existing value and does not execute block when key exists" do
      block_called = false
      result = context.fetch_or_store(:name) do
        block_called = true
        "Default"
      end

      expect(result).to eq("John")
      expect(block_called).to be(false)
    end

    it "stores nil when no value or block provided" do
      result = context.fetch_or_store(:status)

      expect(result).to be_nil
      expect(context.table).to include(status: nil)
    end

    it "overwrites existing value when block is provided and key exists" do
      context[:counter] = 5
      result = context.fetch_or_store(:counter) { 10 }

      expect(result).to eq(5)
      expect(context.table).to include(counter: 5)
    end

    it "handles complex default values" do
      default_hash = { active: true, role: "admin" }
      result = context.fetch_or_store(:settings, default_hash)

      expect(result).to eq(default_hash)
      expect(context.table).to include(settings: default_hash)
    end
  end

  describe "#merge!" do
    context "when given a hash" do
      it "merges new data and returns self" do
        result = context.merge!(email: "john@example.com", active: true)

        expect(result).to be(context)
        expect(context.table).to include(
          name: "John",
          age: 30,
          email: "john@example.com",
          active: true
        )
      end
    end

    context "when given object with to_h" do
      let(:mergeable) do
        object = Object.new
        def object.to_h
          { "status" => "active", "role" => "user" }
        end
        object
      end

      it "converts to hash and merges with symbol keys" do
        context.merge!(mergeable)

        expect(context.table).to include(status: "active", role: "user")
      end
    end

    context "when given empty hash" do
      it "returns self without changes" do
        original_table = context.table.dup
        result = context.merge!({})

        expect(result).to be(context)
        expect(context.table).to eq(original_table)
      end
    end

    it "overwrites existing keys" do
      context.merge!(name: "Jane", age: 25)

      expect(context.table).to eq(name: "Jane", age: 25)
    end
  end

  describe "#delete!" do
    it "deletes existing key and returns value" do
      result = context.delete!(:name)

      expect(result).to eq("John")
      expect(context.table).not_to have_key(:name)
    end

    it "deletes key with string converted to symbol" do
      result = context.delete!("age")

      expect(result).to eq(30)
      expect(context.table).not_to have_key(:age)
    end

    it "returns nil for non-existent key" do
      result = context.delete!(:missing)

      expect(result).to be_nil
    end

    it "executes block for non-existent key" do
      result = context.delete!(:missing) { "not found" }

      expect(result).to eq("not found")
    end
  end

  describe "#clear!" do
    it "clears all data and returns self" do
      result = context.clear!

      expect(result).to be(context)
      expect(context.table).to be_empty
    end
  end

  describe "#eql? and #==" do
    let(:other_context) { described_class.new(name: "John", age: 30) }
    let(:different_context) { described_class.new(name: "Jane", age: 25) }

    it "returns true for contexts with same data" do
      expect(context).to eql(other_context)
      expect(context).to eq(other_context)
    end

    it "returns false for contexts with different data" do
      expect(context).not_to eql(different_context)
      expect(context).not_to eq(different_context)
    end

    it "returns false when compared to non-Context object" do
      expect(context).not_to eql({ name: "John", age: 30 })
      expect(context).not_to eq({ name: "John", age: 30 })
    end
  end

  describe "#key?" do
    it "returns true for existing symbol key" do
      expect(context.key?(:name)).to be(true)
    end

    it "returns true for existing key given as string" do
      expect(context.key?("name")).to be(true)
    end

    it "returns false for non-existent key" do
      expect(context.key?(:missing)).to be(false)
    end
  end

  describe "#dig" do
    let(:initial_data) do
      {
        user: {
          profile: {
            name: "John",
            settings: { theme: "dark" }
          }
        }
      }
    end

    it "digs into nested hash with symbol keys" do
      expect(context.dig(:user, :profile, :name)).to eq("John")
    end

    it "digs into nested hash with string key converted to symbol" do
      expect(context.dig("user", :profile, :settings, :theme)).to eq("dark")
    end

    it "returns nil for non-existent nested path" do
      expect(context.dig(:user, :missing, :key)).to be_nil
    end

    it "returns nil for partial path" do
      expect(context.dig(:user, :profile, :missing)).to be_nil
    end
  end

  describe "#to_h" do
    it "returns the internal table" do
      expect(context.to_h).to eq(context.table)
      expect(context.to_h).to be(context.table)
    end
  end

  describe "#to_s" do
    it "delegates to Utils::Format.to_str" do
      allow(CMDx::Utils::Format).to receive(:to_str).with(context.table).and_return("formatted string")

      expect(context.to_s).to eq("formatted string")
    end
  end

  describe "#each" do
    it "delegates to table" do
      result = []
      context.each { |key, value| result << [key, value] } # rubocop:disable Style/MapIntoArray

      expect(result).to contain_exactly([:name, "John"], [:age, 30])
    end
  end

  describe "#map" do
    it "delegates to table" do
      result = context.map { |key, value| "#{key}:#{value}" }

      expect(result).to contain_exactly("name:John", "age:30")
    end
  end

  describe "method_missing and respond_to_missing?" do
    context "when method name matches existing key" do
      it "returns the value" do
        expect(context.name).to eq("John")
        expect(context.age).to eq(30)
      end

      it "responds to the method" do
        expect(context).to respond_to(:name)
        expect(context).to respond_to(:age)
      end
    end

    context "when method name does not match any key" do
      it "returns nil" do
        expect(context.missing_method).to be_nil
      end

      it "does not respond to the method" do
        expect(context).not_to respond_to(:missing_method)
      end
    end

    context "when method name ends with equals sign" do
      it "stores the value" do
        context.email = "john@example.com"

        expect(context.table).to include(email: "john@example.com")
      end
    end

    context "when checking private method visibility" do
      it "delegates to super for respond_to_missing?" do
        expect(context.respond_to?(:name, true)).to be(true)
        expect(context.respond_to?(:missing, true)).to be(false)
      end
    end
  end
end

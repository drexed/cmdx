# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LazyStruct do
  describe "#initialize" do
    it "creates empty structure with no arguments" do
      struct = described_class.new

      expect(struct.to_h).to eq({})
    end

    it "creates structure from hash" do
      struct = described_class.new(name: "John", age: 30)

      expect(struct.to_h).to eq(name: "John", age: 30)
    end

    it "converts string keys to symbols" do
      struct = described_class.new("name" => "John", "age" => 30)

      expect(struct.to_h).to eq(name: "John", age: 30)
    end

    it "accepts objects that respond to to_h" do
      hash_like = OpenStruct.new(status: "active", count: 5)
      struct = described_class.new(hash_like)

      expect(struct.to_h).to eq(status: "active", count: 5)
    end

    it "raises ArgumentError when argument doesn't respond to to_h" do
      expect { described_class.new("invalid") }.to raise_error(
        ArgumentError,
        "must be respond to `to_h`"
      )
    end
  end

  describe "#[]" do
    subject(:struct) { described_class.new(name: "John", age: 30) }

    it "retrieves value by symbol key" do
      expect(struct[:name]).to eq("John")
    end

    it "retrieves value by string key" do
      expect(struct["name"]).to eq("John")
    end

    it "returns nil for non-existent keys" do
      expect(struct[:missing]).to be_nil
    end
  end

  describe "#fetch!" do
    subject(:struct) { described_class.new(name: "John") }

    it "returns value for existing key" do
      expect(struct.fetch!(:name)).to eq("John")
    end

    it "returns default value for missing key" do
      expect(struct.fetch!(:missing, "default")).to eq("default")
    end

    it "executes block for missing key" do
      result = struct.fetch!(:missing) { "computed" }

      expect(result).to eq("computed")
    end

    it "raises KeyError for missing key without default" do
      expect { struct.fetch!(:missing) }.to raise_error(KeyError)
    end
  end

  describe "#store!" do
    subject(:struct) { described_class.new }

    it "stores value with symbol key" do
      struct.store!(:name, "John")

      expect(struct[:name]).to eq("John")
    end

    it "stores value with string key" do
      struct.store!("age", 30)

      expect(struct[:age]).to eq(30)
    end

    it "returns stored value" do
      result = struct.store!(:name, "John")

      expect(result).to eq("John")
    end

    it "overwrites existing values" do
      struct.store!(:name, "John")
      struct.store!(:name, "Jane")

      expect(struct[:name]).to eq("Jane")
    end
  end

  describe "#[]=" do
    subject(:struct) { described_class.new }

    it "aliases store! method" do
      struct[:name] = "John"

      expect(struct[:name]).to eq("John")
    end
  end

  describe "#merge!" do
    subject(:struct) { described_class.new(name: "John") }

    it "merges hash data" do
      struct.merge!(age: 30, city: "NYC")

      expect(struct.to_h).to eq(name: "John", age: 30, city: "NYC")
    end

    it "overwrites existing keys" do
      struct.merge!(name: "Jane") # rubocop:disable Performance/RedundantMerge

      expect(struct[:name]).to eq("Jane")
    end

    it "returns self for chaining" do
      result = struct.merge!(age: 30)

      expect(result).to be(struct)
    end

    it "accepts objects that respond to to_h" do
      hash_like = OpenStruct.new(status: "active")
      struct.merge!(hash_like)

      expect(struct[:status]).to eq("active")
    end
  end

  describe "#delete!" do
    subject(:struct) { described_class.new(name: "John", age: 30) }

    it "deletes existing key and returns value" do
      result = struct.delete!(:name)

      expect(result).to eq("John")
      expect(struct[:name]).to be_nil
    end

    it "returns nil for non-existent key" do
      result = struct.delete!(:missing)

      expect(result).to be_nil
    end

    it "executes block for non-existent key" do
      result = struct.delete!(:missing) { "not found" }

      expect(result).to eq("not found")
    end

    it "works with string keys" do
      result = struct.delete!("age")

      expect(result).to eq(30)
      expect(struct[:age]).to be_nil
    end
  end

  describe "#delete_field!" do
    subject(:struct) { described_class.new(name: "John") }

    it "aliases delete! method" do
      result = struct.delete_field!(:name)

      expect(result).to eq("John")
      expect(struct[:name]).to be_nil
    end
  end

  describe "#eql?" do
    let(:struct_one) { described_class.new(name: "John", age: 30) }
    let(:struct_two) { described_class.new(name: "John", age: 30) }
    let(:struct_three) { described_class.new(name: "Jane", age: 25) }

    it "returns true for structs with same data" do
      expect(struct_one.eql?(struct_two)).to be true
    end

    it "returns false for structs with different data" do
      expect(struct_one.eql?(struct_three)).to be false
    end

    it "returns false for non-LazyStruct objects" do
      expect(struct_one.eql?({})).to be false
    end
  end

  describe "#==" do
    subject(:struct) { described_class.new(name: "John") }

    it "aliases eql? method" do
      other = described_class.new(name: "John")

      expect(struct == other).to be true
    end
  end

  describe "#dig" do
    subject(:struct) do
      described_class.new(
        user: {
          profile: { name: "John", details: { age: 30 } },
          settings: { theme: "dark" }
        }
      )
    end

    it "extracts nested values" do
      expect(struct.dig(:user, :profile, :name)).to eq("John")
    end

    it "extracts deeply nested values" do
      expect(struct.dig(:user, :profile, :details, :age)).to eq(30)
    end

    it "returns nil for missing paths" do
      expect(struct.dig(:user, :missing, :path)).to be_nil
    end

    it "returns nil for partially missing paths" do
      expect(struct.dig(:user, :profile, :missing)).to be_nil
    end
  end

  describe "#each_pair" do
    subject(:struct) { described_class.new(name: "John", age: 30) }

    it "iterates over key-value pairs" do
      pairs = []
      struct.each_pair { |key, value| pairs << [key, value] }

      expect(pairs).to contain_exactly([:name, "John"], [:age, 30])
    end

    it "returns hash when block given" do
      result = struct.each_pair { |_k, _v| nil }

      expect(result).to eq(struct.to_h)
    end

    it "returns enumerator when no block given" do
      result = struct.each_pair

      expect(result).to be_a(Enumerator)
      expect(result.to_a).to contain_exactly([:name, "John"], [:age, 30])
    end
  end

  describe "#to_h" do
    subject(:struct) { described_class.new(name: "John", age: 30) }

    it "returns hash representation" do
      expect(struct.to_h).to eq(name: "John", age: 30)
    end

    it "passes block to underlying hash" do
      result = struct.to_h { |k, v| [k.to_s, v.to_s] }

      expect(result).to eq("name" => "John", "age" => "30")
    end
  end

  describe "#inspect" do
    it "shows empty structure" do
      struct = described_class.new

      expect(struct.inspect).to eq("#<CMDx::LazyStruct>")
    end

    it "shows structure with single field" do
      struct = described_class.new(name: "John")

      expect(struct.inspect).to eq('#<CMDx::LazyStruct:name="John">')
    end

    it "shows structure with multiple fields" do
      struct = described_class.new(name: "John", age: 30)

      expect(struct.inspect).to match(/#<CMDx::LazyStruct:name="John" :age=30>/)
    end
  end

  describe "#to_s" do
    subject(:struct) { described_class.new(name: "John") }

    it "aliases inspect method" do
      expect(struct.to_s).to eq(struct.inspect)
    end
  end

  describe "dynamic method access" do
    subject(:struct) { described_class.new(name: "John", age: 30) }

    it "provides getter access for existing fields" do
      expect(struct.name).to eq("John")
      expect(struct.age).to eq(30)
    end

    it "returns nil for non-existent fields" do
      expect(struct.missing).to be_nil
    end

    it "provides setter access with = methods" do
      struct.city = "NYC"

      expect(struct[:city]).to eq("NYC")
    end

    it "overwrites existing values with setters" do
      struct.name = "Jane"

      expect(struct.name).to eq("Jane")
    end
  end

  describe "#respond_to_missing?" do
    subject(:struct) { described_class.new(name: "John") }

    it "returns true for existing field names" do
      expect(struct.respond_to?(:name)).to be true
    end

    it "returns false for setter methods" do
      expect(struct.respond_to?(:name=)).to be false
    end

    it "returns false for non-existent fields" do
      expect(struct.respond_to?(:missing)).to be false
    end

    it "delegates to super for standard methods" do
      expect(struct.respond_to?(:class)).to be true
    end
  end

  describe "error handling" do
    subject(:struct) { described_class.new }

    it "raises TypeError for invalid key types" do
      expect { struct[Object.new] }.to raise_error(
        TypeError,
        /is not a symbol nor a string/
      )
    end

    it "raises TypeError when storing with invalid key types" do
      expect { struct.store!(Object.new, "value") }.to raise_error(
        TypeError,
        /is not a symbol nor a string/
      )
    end
  end

  describe "integration scenarios" do
    it "works with nested LazyStruct instances" do
      inner = described_class.new(name: "John")
      outer = described_class.new(user: inner, count: 5)

      expect(outer.user.name).to eq("John")
      expect(outer.count).to eq(5)
    end

    it "maintains data consistency through various operations" do
      struct = described_class.new(initial: "value")
      struct.merge!(added: "data") # rubocop:disable Performance/RedundantMerge
      struct[:updated] = "field"
      struct.delete!(:initial)

      expect(struct.to_h).to eq(added: "data", updated: "field")
    end

    it "handles mixed key types consistently" do
      struct = described_class.new("string_key" => "value1")
      struct[:symbol_key] = "value2"
      struct.method_key = "value3"

      expect(struct["string_key"]).to eq("value1")
      expect(struct.symbol_key).to eq("value2")
      expect(struct[:method_key]).to eq("value3")
    end
  end
end

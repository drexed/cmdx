# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LazyStruct do
  describe "#initialize" do
    context "when initialized with a hash" do
      it "stores the hash data with symbol keys" do
        struct = described_class.new(name: "John", age: 30)

        expect(struct[:name]).to eq("John")
        expect(struct[:age]).to eq(30)
      end

      it "converts string keys to symbols" do
        struct = described_class.new("name" => "John", "age" => 30)

        expect(struct[:name]).to eq("John")
        expect(struct[:age]).to eq(30)
      end
    end

    context "when initialized with an empty hash" do
      it "creates an empty struct" do
        struct = described_class.new

        expect(struct.to_h).to eq({})
      end
    end

    context "when initialized with hash-like object" do
      it "accepts objects that respond to to_h" do
        hash_like = double("HashLike", to_h: { name: "John" })
        allow(hash_like).to receive(:transform_keys).and_return({ name: "John" })

        struct = described_class.new(hash_like)

        expect(struct[:name]).to eq("John")
      end
    end

    context "when initialized with invalid argument" do
      it "raises ArgumentError for objects that don't respond to to_h" do
        expect { described_class.new("invalid") }.to raise_error(ArgumentError, "must be respond to `to_h`")
      end
    end
  end

  describe "#[]" do
    let(:struct) { described_class.new(name: "John", age: 30) }

    context "when key exists" do
      it "returns value for symbol key" do
        expect(struct[:name]).to eq("John")
      end

      it "returns value for string key" do
        expect(struct["name"]).to eq("John")
      end
    end

    context "when key does not exist" do
      it "returns nil for missing symbol key" do
        expect(struct[:missing]).to be_nil
      end

      it "returns nil for missing string key" do
        expect(struct["missing"]).to be_nil
      end
    end
  end

  describe "#fetch!" do
    let(:struct) { described_class.new(name: "John", age: 30) }

    context "when key exists" do
      it "returns value for existing symbol key" do
        expect(struct.fetch!(:name)).to eq("John")
      end

      it "returns value for existing string key" do
        expect(struct.fetch!("name")).to eq("John")
      end
    end

    context "when key does not exist" do
      it "raises KeyError for missing key without default" do
        expect { struct.fetch!(:missing) }.to raise_error(KeyError)
      end

      it "returns default value when provided" do
        expect(struct.fetch!(:missing, "default")).to eq("default")
      end

      it "returns block result when block provided" do
        result = struct.fetch!(:missing) { "computed default" }

        expect(result).to eq("computed default")
      end
    end
  end

  describe "#store!" do
    let(:struct) { described_class.new }

    it "stores value with symbol key" do
      result = struct.store!(:name, "John")

      expect(result).to eq("John")
      expect(struct[:name]).to eq("John")
    end

    it "stores value with string key converted to symbol" do
      struct.store!("age", 30)

      expect(struct[:age]).to eq(30)
    end

    it "overwrites existing values" do
      struct.store!(:name, "John")
      struct.store!(:name, "Jane")

      expect(struct[:name]).to eq("Jane")
    end
  end

  describe "#[]=" do
    let(:struct) { described_class.new }

    it "is an alias for store!" do
      struct[:name] = "John"

      expect(struct[:name]).to eq("John")
    end

    it "converts string keys to symbols" do
      struct["age"] = 30

      expect(struct[:age]).to eq(30)
    end
  end

  describe "#merge!" do
    let(:struct) { described_class.new(name: "John") }

    context "when merging a hash" do
      it "adds new key-value pairs" do
        result = struct.merge!(age: 30, city: "NYC")

        expect(result).to eq(struct)
        expect(struct[:age]).to eq(30)
        expect(struct[:city]).to eq("NYC")
        expect(struct[:name]).to eq("John")
      end

      it "overwrites existing keys" do
        struct.merge!(name: "Jane", age: 25)

        expect(struct[:name]).to eq("Jane")
        expect(struct[:age]).to eq(25)
      end
    end

    context "when merging hash-like object" do
      it "accepts objects that respond to to_h" do
        hash_like = double("HashLike", to_h: { age: 30 })

        struct.merge!(hash_like)

        expect(struct[:age]).to eq(30)
      end
    end

    context "when merging with empty hash" do
      it "returns self unchanged" do
        original_hash = struct.to_h.dup
        result = struct.merge!({})

        expect(result).to eq(struct)
        expect(struct.to_h).to eq(original_hash)
      end
    end

    it "converts string keys to symbols" do
      struct["email"] = "john@example.com"

      expect(struct[:email]).to eq("john@example.com")
    end
  end

  describe "#delete!" do
    let(:struct) { described_class.new(name: "John", age: 30) }

    context "when key exists" do
      it "deletes and returns the value" do
        result = struct.delete!(:name)

        expect(result).to eq("John")
        expect(struct[:name]).to be_nil
      end

      it "converts string key to symbol" do
        result = struct.delete!("age")

        expect(result).to eq(30)
        expect(struct[:age]).to be_nil
      end
    end

    context "when key does not exist" do
      it "returns nil" do
        result = struct.delete!(:missing)

        expect(result).to be_nil
      end

      it "returns block result when block provided" do
        result = struct.delete!(:missing) { "not found" }

        expect(result).to eq("not found")
      end
    end
  end

  describe "#delete_field!" do
    let(:struct) { described_class.new(name: "John") }

    it "is an alias for delete!" do
      result = struct.delete_field!(:name)

      expect(result).to eq("John")
      expect(struct[:name]).to be_nil
    end
  end

  describe "#eql?" do
    let(:struct1) { described_class.new(name: "John", age: 30) }
    let(:struct2) { described_class.new(name: "John", age: 30) }
    let(:struct3) { described_class.new(name: "Jane", age: 25) }

    context "when structs have same data" do
      it "returns true" do
        expect(struct1.eql?(struct2)).to be(true)
      end
    end

    context "when structs have different data" do
      it "returns false" do
        expect(struct1.eql?(struct3)).to be(false)
      end
    end

    context "when comparing with different class" do
      it "returns false" do
        expect(struct1.eql?({})).to be(false)
      end
    end

    context "when comparing with nil" do
      it "returns false" do
        expect(struct1.eql?(nil)).to be(false)
      end
    end
  end

  describe "#==" do
    let(:struct1) { described_class.new(name: "John") }
    let(:struct2) { described_class.new(name: "John") }

    it "is an alias for eql?" do
      expect(struct1 == struct2).to be(true)
    end
  end

  describe "#dig" do
    let(:struct) { described_class.new(user: { profile: { name: "John" } }, data: [1, 2, 3]) }

    context "when path exists" do
      it "returns nested value with symbol keys" do
        result = struct.dig(:user, :profile, :name)

        expect(result).to eq("John")
      end

      it "returns nested value with string keys" do
        result = struct.dig("user", :profile, :name)

        expect(result).to eq("John")
      end

      it "returns nested value with mixed key types" do
        result = struct.dig(:user, :profile, :name)

        expect(result).to eq("John")
      end

      it "returns array elements" do
        result = struct.dig(:data, 1)

        expect(result).to eq(2)
      end
    end

    context "when path does not exist" do
      it "returns nil for missing intermediate key" do
        result = struct.dig(:user, :missing, :name)

        expect(result).to be_nil
      end

      it "returns nil for missing final key" do
        result = struct.dig(:user, :profile, :missing)

        expect(result).to be_nil
      end
    end

    context "when key cannot be converted to symbol" do
      it "raises TypeError" do
        expect { struct[Object.new] }.to raise_error(TypeError, /is not a symbol nor a string/)
      end
    end
  end

  describe "#each_pair" do
    let(:struct) { described_class.new(name: "John", age: 30) }

    context "when block given" do
      it "yields each key-value pair" do
        pairs = []
        result = struct.each_pair { |key, value| pairs << [key, value] }

        expect(pairs).to contain_exactly([:name, "John"], [:age, 30])
        expect(result).to eq({ name: "John", age: 30 })
      end
    end

    context "when no block given" do
      it "returns an enumerator" do
        result = struct.each_pair

        expect(result).to be_an(Enumerator)
        expect(result.to_a).to contain_exactly([:name, "John"], [:age, 30])
      end
    end
  end

  describe "#to_h" do
    let(:struct) { described_class.new(name: "John", age: 30) }

    context "when no block given" do
      it "returns hash with symbol keys" do
        result = struct.to_h

        expect(result).to eq({ name: "John", age: 30 })
        expect(result).to be_a(Hash)
      end
    end

    context "when block given" do
      it "transforms the hash" do
        result = struct.to_h { |key, value| [key.to_s, value.to_s] }

        expect(result).to eq({ "name" => "John", "age" => "30" })
      end
    end
  end

  describe "#inspect" do
    context "when struct has data" do
      it "returns formatted string representation" do
        struct = described_class.new(name: "John", age: 30)

        result = struct.inspect

        expect(result).to match(/#<CMDx::LazyStruct/)
        expect(result).to include(':name="John"')
        expect(result).to include(":age=30")
      end
    end

    context "when struct is empty" do
      it "returns class name only" do
        struct = described_class.new

        result = struct.inspect

        expect(result).to eq("#<CMDx::LazyStruct>")
      end
    end
  end

  describe "#to_s" do
    let(:struct) { described_class.new(name: "John") }

    it "is an alias for inspect" do
      expect(struct.to_s).to eq(struct.inspect)
    end
  end

  describe "dynamic method access" do
    let(:struct) { described_class.new(name: "John", age: 30) }

    describe "getter methods" do
      context "when attribute exists" do
        it "returns the stored value" do
          expect(struct.name).to eq("John")
          expect(struct.age).to eq(30)
        end
      end

      context "when attribute does not exist" do
        it "returns nil" do
          expect(struct.missing_attribute).to be_nil
        end
      end
    end

    describe "setter methods" do
      it "sets new attributes" do
        struct.email = "john@example.com"

        expect(struct.email).to eq("john@example.com")
        expect(struct[:email]).to eq("john@example.com")
      end

      it "overwrites existing attributes" do
        struct.name = "Jane"

        expect(struct.name).to eq("Jane")
      end

      it "returns the assigned value" do
        result = (struct.city = "NYC")

        expect(result).to eq("NYC")
      end
    end
  end

  describe "#respond_to?" do
    let(:struct) { described_class.new(name: "John") }

    context "when method corresponds to existing attribute" do
      it "returns true" do
        expect(struct.respond_to?(:name)).to be(true)
      end
    end

    context "when method corresponds to setter for existing attribute" do
      it "returns false (not implemented in respond_to_missing?)" do
        expect(struct.respond_to?(:name=)).to be(false)
      end
    end

    context "when method does not correspond to attribute" do
      it "returns false" do
        expect(struct.respond_to?(:missing_attribute)).to be(false)
      end
    end

    context "when method is a standard method" do
      it "returns true for to_h" do
        expect(struct.respond_to?(:to_h)).to be(true)
      end

      it "returns true for inspect" do
        expect(struct.respond_to?(:inspect)).to be(true)
      end

      it "returns true for eql?" do
        expect(struct.respond_to?(:eql?)).to be(true)
      end
    end
  end

  describe "complex usage scenarios" do
    context "when used with nested structures" do
      it "handles complex nested data" do
        struct = described_class.new(
          user: {
            profile: { name: "John", age: 30 },
            preferences: { theme: "dark", notifications: true }
          },
          metadata: { created_at: Time.now }
        )

        expect(struct.dig(:user, :profile, :name)).to eq("John")
        expect(struct.dig(:user, :preferences, :theme)).to eq("dark")
        expect(struct.user[:profile][:age]).to eq(30)
      end
    end

    context "when used for dynamic attribute building" do
      it "allows progressive attribute assignment" do
        struct = described_class.new

        struct.step_1_complete = true
        struct.step_2_data = { items: [] }
        struct[:step_3_timestamp] = Time.now

        expect(struct.step_1_complete).to be(true)
        expect(struct[:step_2_data]).to eq({ items: [] })
        expect(struct.respond_to?(:step_3_timestamp)).to be(true)
      end
    end

    context "when performing operations on copies" do
      it "maintains independence between instances" do
        original = described_class.new(name: "John")
        copy = described_class.new(original.to_h)

        copy.name = "Jane"
        copy.age = 25

        expect(original.name).to eq("John")
        expect(original.respond_to?(:age)).to be(false)
        expect(copy.name).to eq("Jane")
        expect(copy.age).to eq(25)
      end
    end
  end
end

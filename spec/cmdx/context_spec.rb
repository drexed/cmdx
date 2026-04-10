# frozen_string_literal: true

RSpec.describe CMDx::Context do
  describe ".build" do
    it "builds from nil" do
      ctx = described_class.build(nil)
      expect(ctx).to be_a(described_class)
      expect(ctx).to be_empty
    end

    it "builds from a hash" do
      ctx = described_class.build(name: "Alice", age: 30)
      expect(ctx[:name]).to eq("Alice")
      expect(ctx[:age]).to eq(30)
    end

    it "normalizes string keys to symbols" do
      ctx = described_class.build("name" => "Bob")
      expect(ctx[:name]).to eq("Bob")
    end

    it "builds from an existing context" do
      original = described_class.build(x: 1)
      ctx = described_class.build(original)
      expect(ctx).to equal(original)
    end

    it "duplicates a frozen context" do
      original = described_class.build(x: 1)
      original.freeze
      ctx = described_class.build(original)
      expect(ctx).not_to equal(original)
      expect(ctx[:x]).to eq(1)
    end

    it "raises for unsupported input" do
      expect { described_class.build(42) }.to raise_error(ArgumentError, /Cannot build Context/)
    end
  end

  describe "access" do
    subject(:ctx) { described_class.build(name: "Alice") }

    it "supports method-style access" do
      expect(ctx.name).to eq("Alice")
    end

    it "supports hash-style access" do
      expect(ctx[:name]).to eq("Alice")
    end

    it "returns nil for undefined keys" do
      expect(ctx.missing_key).to be_nil
    end

    it "supports method-style assignment" do
      ctx.age = 25
      expect(ctx[:age]).to eq(25)
    end

    it "supports hash-style assignment" do
      ctx[:role] = "admin"
      expect(ctx.role).to eq("admin")
    end

    it "supports fetch with default" do
      expect(ctx.fetch(:missing, "default")).to eq("default")
    end

    it "supports fetch_or_store" do
      expect(ctx.fetch_or_store(:counter, 0)).to eq(0)
      ctx[:counter] = 5
      expect(ctx.fetch_or_store(:counter, 0)).to eq(5)
    end

    it "supports key?" do
      expect(ctx.key?(:name)).to be(true)
      expect(ctx.key?(:nope)).to be(false)
    end

    it "supports merge!" do
      ctx.merge!(x: 1, y: 2)
      expect(ctx[:x]).to eq(1)
      expect(ctx[:y]).to eq(2)
    end

    it "supports delete!" do
      ctx.delete!(:name)
      expect(ctx[:name]).to be_nil
    end

    it "to_h returns a dup" do
      hash = ctx.to_h
      hash[:name] = "modified"
      expect(ctx[:name]).to eq("Alice")
    end
  end

  describe "#freeze" do
    it "prevents further modification" do
      ctx = described_class.build(x: 1)
      ctx.freeze
      expect(ctx).to be_frozen
      expect { ctx[:y] = 2 }.to raise_error(FrozenError)
    end
  end
end

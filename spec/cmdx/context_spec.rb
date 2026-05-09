# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Context do
  describe ".build" do
    it "returns the same instance when given an unfrozen Context" do
      ctx = described_class.new(a: 1)
      expect(described_class.build(ctx)).to be(ctx)
    end

    it "wraps a frozen Context in a new instance" do
      ctx = described_class.new(a: 1).freeze
      built = described_class.build(ctx)

      expect(built).not_to be(ctx)
      expect(built.to_h).to eq(a: 1)
    end

    it "unwraps an object that responds to #context" do
      ctx = described_class.new(a: 1)
      holder = Struct.new(:context).new(ctx)

      expect(described_class.build(holder)).to be(ctx)
    end

    it "builds from a hash" do
      built = described_class.build(a: 1, b: 2)
      expect(built.to_h).to eq(a: 1, b: 2)
    end

    it "builds an empty context by default" do
      expect(described_class.build).to be_empty
    end
  end

  describe "#initialize" do
    it "accepts a hash and stringified keys are symbolized" do
      ctx = described_class.new("a" => 1, b: 2)
      expect(ctx.to_h).to eq(a: 1, b: 2)
    end

    it "accepts any object with to_hash" do
      hashable = Class.new { def to_hash = { x: 1 } }.new
      expect(described_class.new(hashable).to_h).to eq(x: 1)
    end

    it "accepts any object with to_h" do
      hashish = Class.new { def to_h = { y: 2 } }.new
      expect(described_class.new(hashish).to_h).to eq(y: 2)
    end

    it "raises ArgumentError for objects that respond to neither" do
      expect { described_class.new(Object.new) }
        .to raise_error(ArgumentError, "must respond to `to_h` or `to_hash`")
    end
  end

  describe "key access" do
    subject(:ctx) { described_class.new(a: 1, b: 2) }

    it "reads via []" do
      expect(ctx[:a]).to eq(1)
      expect(ctx["a"]).to eq(1)
    end

    it "writes via store / []=" do
      ctx.store(:c, 3)
      ctx["d"] = 4
      expect(ctx.to_h).to eq(a: 1, b: 2, c: 3, d: 4)
    end

    it "fetches with a default" do
      expect(ctx.fetch(:missing, :default)).to eq(:default)
      expect(ctx.fetch(:a)).to eq(1)
    end

    it "fetches with a block" do
      expect(ctx.fetch(:missing) { :block }).to eq(:block) # rubocop:disable Style/RedundantFetchBlock
    end

    it "raises on fetch miss without default" do
      expect { ctx.fetch(:missing) }.to raise_error(KeyError)
    end

    it "digs into nested values" do
      nested = described_class.new(a: { b: { c: 1 } })
      expect(nested.dig(:a, :b, :c)).to eq(1)
    end
  end

  describe "#retrieve" do
    subject(:ctx) { described_class.new }

    it "returns the existing value without writing when present" do
      ctx.store(:a, 1)
      expect(ctx.retrieve(:a, 99)).to eq(1)
      expect(ctx[:a]).to eq(1)
    end

    it "stores and returns the default when missing" do
      expect(ctx.retrieve(:a, 42)).to eq(42)
      expect(ctx[:a]).to eq(42)
    end

    it "stores and returns the block result when missing" do
      expect(ctx.retrieve(:a) { :computed }).to eq(:computed)
      expect(ctx[:a]).to eq(:computed)
    end

    it "prefers the block over the default" do
      expect(ctx.retrieve(:a, :fallback) { :block }).to eq(:block)
    end
  end

  describe "#merge" do
    it "returns self after merging a hash" do
      ctx = described_class.new(a: 1)
      expect(ctx.merge(b: 2)).to be(ctx)
      expect(ctx.to_h).to eq(a: 1, b: 2)
    end

    it "overwrites existing keys" do
      ctx = described_class.new(a: 1)
      ctx.merge(a: 99)
      expect(ctx[:a]).to eq(99)
    end

    it "accepts another Context" do
      ctx = described_class.new(a: 1)
      other = described_class.new(b: 2)
      ctx.merge(other)
      expect(ctx.to_h).to eq(a: 1, b: 2)
    end
  end

  describe "#deep_merge" do
    it "returns self" do
      ctx = described_class.new(a: 1)
      expect(ctx.deep_merge(b: 2)).to be(ctx)
    end

    it "merges nested hashes recursively instead of replacing them" do
      ctx = described_class.new(user: { name: "Ada", prefs: { theme: "dark" } })
      ctx.deep_merge(user: { age: 36, prefs: { lang: "en" } })
      expect(ctx.user).to eq(name: "Ada", age: 36, prefs: { theme: "dark", lang: "en" })
    end

    it "right-hand scalar replaces left-hand hash and vice versa" do
      ctx = described_class.new(x: { a: 1 })
      ctx.deep_merge(x: 42)
      expect(ctx.x).to eq(42)

      ctx = described_class.new(y: 5)
      ctx.deep_merge(y: { b: 2 })
      expect(ctx.y).to eq(b: 2)
    end

    it "does not mutate nested source hashes" do
      source = { user: { name: "Ada" } }
      ctx = described_class.new(user: { email: "a@b" })
      ctx.deep_merge(source)
      expect(source[:user]).to eq(name: "Ada")
    end
  end

  describe "predicates and introspection" do
    subject(:ctx) { described_class.new(a: 1) }

    it "key? uses symbol-coerced keys" do
      expect(ctx.key?(:a)).to be(true)
      expect(ctx.key?("a")).to be(true)
      expect(ctx.key?(:b)).to be(false)
    end

    it "keys and values" do
      expect(ctx.keys).to eq([:a])
      expect(ctx.values).to eq([1])
    end

    it "empty? and size" do
      expect(ctx).not_to be_empty
      expect(ctx.size).to eq(1)
      expect(described_class.new).to be_empty
    end
  end

  describe "iteration" do
    subject(:ctx) { described_class.new(a: 1, b: 2) }

    it "each yields symbol/value pairs" do
      pairs = []
      ctx.each { |k, v| pairs << [k, v] } # rubocop:disable Style/MapIntoArray
      expect(pairs).to eq([[:a, 1], [:b, 2]])
    end

    it "each_key and each_value" do
      expect(ctx.each_key.to_a).to eq(%i[a b])
      expect(ctx.each_value.to_a).to eq([1, 2])
    end
  end

  describe "#delete and #clear" do
    it "delete removes the key and returns its value" do
      ctx = described_class.new(a: 1)
      expect(ctx.delete(:a)).to eq(1)
      expect(ctx).to be_empty
    end

    it "delete uses the block when absent" do
      ctx = described_class.new
      result = ctx.delete(:missing) { :default }
      expect(result).to eq(:default)
    end

    it "clear empties the table and returns self" do
      ctx = described_class.new(a: 1)
      expect(ctx.clear).to be(ctx)
      expect(ctx).to be_empty
    end
  end

  describe "equality" do
    it "eql? is true for contexts with equal hashes" do
      a = described_class.new(a: 1)
      b = described_class.new(a: 1)
      expect(a).to eql(b)
    end

    it "eql? is false for different classes" do
      expect(described_class.new(a: 1)).not_to eql({ a: 1 })
    end

    it "hash matches the underlying table" do
      ctx = described_class.new(a: 1)
      expect(ctx.hash).to eq({ a: 1 }.hash)
    end
  end

  describe "#to_s" do
    it "renders space-separated k=value.inspect pairs" do
      ctx = described_class.new(a: 1, name: "Jane")
      expect(ctx.to_s).to eq('a=1 name="Jane"')
    end
  end

  describe "#deep_dup" do
    it "returns a new context with independent nested data" do
      ctx = described_class.new(a: { b: [1, 2] })
      copy = ctx.deep_dup

      copy[:a][:b] << 3

      expect(ctx[:a][:b]).to eq([1, 2])
      expect(copy[:a][:b]).to eq([1, 2, 3])
      expect(copy).not_to be(ctx)
    end

    it "preserves immutable scalars" do
      ctx = described_class.new(n: 1, s: :x, t: true, f: false, z: nil)
      copy = ctx.deep_dup
      expect(copy.to_h).to eq(n: 1, s: :x, t: true, f: false, z: nil)
    end

    it "falls back to the original value when dup raises" do
      unduppable = Class.new { def dup = raise "nope" }.new
      ctx = described_class.new(val: unduppable)

      expect(ctx.deep_dup[:val]).to be(unduppable)
    end
  end

  describe "#freeze" do
    it "freezes both the context and its table" do
      ctx = described_class.new(a: 1).freeze
      expect(ctx).to be_frozen
      expect(ctx.to_h).to be_frozen
    end
  end

  describe "dynamic accessors" do
    subject(:ctx) { described_class.new(name: "Jane") }

    it "reads via method name" do
      expect(ctx.name).to eq("Jane")
    end

    it "writes via foo= method" do
      ctx.age = 30
      expect(ctx[:age]).to eq(30)
    end

    it "foo? returns boolean based on truthiness" do
      ctx.enabled = false
      ctx.ready = "yes"

      expect(ctx.enabled?).to be(false)
      expect(ctx.ready?).to be(true)
      expect(ctx.unknown?).to be(false)
    end

    it "returns nil for unknown keys (dynamic reader)" do
      expect(ctx.missing).to be_nil
    end

    it "respond_to? is true for existing keys and setter suffixes" do
      expect(ctx.respond_to?(:name)).to be(true)
      expect(ctx.respond_to?(:new_thing=)).to be(true)
      expect(ctx.respond_to?(:ready?)).to be(true)
    end
  end

  describe "strict mode" do
    subject(:ctx) { described_class.new(name: "Jane") }

    it "strict? is false by default" do
      expect(ctx.strict?).to be(false)
    end

    it "strict? reflects any truthy/falsy assignment" do
      ctx.strict = true
      expect(ctx.strict?).to be(true)

      ctx.strict = nil
      expect(ctx.strict?).to be(false)
    end

    context "when strict is enabled" do
      before { ctx.strict = true }

      it "raises UnknownAccessorError for unknown dynamic reads" do
        expect { ctx.missing }
          .to raise_error(CMDx::UnknownAccessorError, /unknown context key :missing \(strict mode\)/)
      end

      it "still returns existing keys via dynamic reader" do
        expect(ctx.name).to eq("Jane")
      end

      it "still assigns via foo=" do
        ctx.age = 30
        expect(ctx[:age]).to eq(30)
      end

      it "still allows foo? predicates for unknown keys without raising" do
        expect(ctx.unknown?).to be(false)
      end

      it "does not affect [] access for unknown keys" do
        expect(ctx[:missing]).to be_nil
      end

      it "does not affect fetch without default" do
        expect { ctx.fetch(:missing) }.to raise_error(KeyError)
      end
    end
  end

  describe "#as_json" do
    it "returns to_h" do
      ctx = described_class.new(a: 1, b: "x")
      expect(ctx.as_json).to eq(ctx.to_h)
    end
  end

  describe "#to_json" do
    it "emits a JSON string with symbol keys stringified" do
      ctx = described_class.new(a: 1, b: "x")
      expect(JSON.parse(ctx.to_json)).to eq("a" => 1, "b" => "x")
    end

    it "serializes nested contexts" do
      inner = described_class.new(n: 2)
      outer = described_class.new(inner:, label: "outer")

      expect(JSON.parse(outer.to_json)).to eq(
        "inner" => { "n" => 2 },
        "label" => "outer"
      )
    end
  end
end

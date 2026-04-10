# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Context do
  describe ".new" do
    it "builds from a hash and symbolizes keys" do
      ctx = described_class.new("foo" => 1, bar: 2)
      expect(ctx[:foo]).to eq(1)
      expect(ctx["foo"]).to eq(1)
      expect(ctx.to_h.keys).to all(be_a(Symbol))
    end

    it "accepts objects responding to to_hash" do
      obj = Object.new
      def obj.to_hash
        { "x" => 3 }
      end
      expect(described_class.new(obj)[:x]).to eq(3)
    end
  end

  describe ".build" do
    it "reuses an unfrozen Context instance" do
      ctx = described_class.new(a: 1)
      expect(described_class.build(ctx)).to equal(ctx)
    end

    it "wraps a plain hash in a new Context" do
      ctx = described_class.build("k" => "v")
      expect(ctx).to be_a(described_class)
      expect(ctx[:k]).to eq("v")
    end
  end

  describe "#[], #[]=, #store" do
    it "reads and writes with string or symbol keys interchangeably" do
      ctx = described_class.new
      ctx[:a] = 1
      expect(ctx["a"]).to eq(1)
      ctx.store("b", 2)
      expect(ctx[:b]).to eq(2)
    end
  end

  describe "#fetch, #fetch_or_store" do
    let(:ctx) { described_class.new(existing: 10) }

    it "fetch uses symbolized keys, default value, and lazy block default" do
      expect(ctx.fetch(:existing)).to eq(10)
      expect(ctx.fetch("existing")).to eq(10)
      expect(ctx.fetch(:missing, 99)).to eq(99)
      calls = 0
      expect(ctx.fetch("existing") { calls += 1 }).to eq(10)
      expect(calls).to eq(0)
      expect(ctx.fetch(:missing) do
        calls += 1
        7
      end).to eq(7)
      expect(calls).to eq(1)
    end

    it "fetch_or_store sets and returns a computed value when missing" do
      expect(ctx.fetch_or_store(:other) { 42 }).to eq(42)
      expect(ctx[:other]).to eq(42)
    end

    it "fetch_or_store uses the given value when no block" do
      expect(ctx.fetch_or_store(:z, 5)).to eq(5)
      expect(ctx[:z]).to eq(5)
    end
  end

  describe "#merge!, #delete!, #clear!" do
    let(:ctx) { described_class.new(a: 1) }

    it "merge! symbolizes keys and returns self" do
      expect(ctx.merge!("b" => 2)).to equal(ctx)
      expect(ctx[:b]).to eq(2)
    end

    it "delete! removes by string or symbol" do
      ctx.delete!("a")
      expect(ctx.key?(:a)).to be false
    end

    it "clear! empties the table" do
      ctx.clear!
      expect(ctx.to_h).to be_empty
    end
  end

  describe "#key?, #dig, #keys, #values, #each" do
    let(:ctx) { described_class.new(outer: { inner: 7 }) }

    it "delegates hash-like introspection" do
      expect(ctx.key?("outer")).to be true
      expect(ctx.dig(:outer, :inner)).to eq(7)
      expect(ctx.keys).to eq([:outer])
      expect(ctx.values.size).to eq(1)

      expect { |b| ctx.each(&b) }.to yield_successive_args([:outer, { inner: 7 }])
    end
  end

  describe "#eql?, #==" do
    it "compares table contents" do
      a = described_class.new(x: 1)
      b = described_class.new("x" => 1)
      expect(a).to eq(b)
      expect(a).to eql(b)
      expect(a == Object.new).to be false
    end
  end

  describe "#to_h, #to_s" do
    let(:ctx) { described_class.new(n: 1) }

    it "to_h returns the symbol-keyed table" do
      expect(ctx.to_h).to eq({ n: 1 })
    end

    it "to_s formats like Utils::Format.to_str" do
      expect(ctx.to_s).to include("n:")
    end
  end

  describe "dynamic accessors via method_missing" do
    let(:ctx) { described_class.new(count: 0) }

    it "reads and writes attributes by name" do
      expect(ctx.count).to eq(0)
      ctx.count = 3
      expect(ctx[:count]).to eq(3)
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Context do
  describe ".build" do
    it "builds from a Hash" do
      ctx = described_class.build(name: "Juan")
      expect(ctx[:name]).to eq("Juan")
    end

    it "builds from nil" do
      ctx = described_class.build(nil)
      expect(ctx.empty?).to be true
    end

    it "reuses unfrozen contexts" do
      original = described_class.new(a: 1)
      expect(described_class.build(original)).to be(original)
    end

    it "duplicates frozen contexts" do
      original = described_class.new(a: 1)
      original.freeze
      built = described_class.build(original)
      expect(built).not_to be(original)
      expect(built[:a]).to eq(1)
    end
  end

  describe "bracket access" do
    subject(:ctx) { described_class.new(name: "World") }

    it "reads with []" do
      expect(ctx[:name]).to eq("World")
    end

    it "writes with []=" do
      ctx[:age] = 30
      expect(ctx[:age]).to eq(30)
    end

    it "symbolizes string keys" do
      ctx["foo"] = "bar"
      expect(ctx[:foo]).to eq("bar")
    end
  end

  describe "method_missing" do
    subject(:ctx) { described_class.new(name: "test") }

    it "reads via method call" do
      expect(ctx.name).to eq("test")
    end

    it "writes via setter" do
      ctx.age = 25
      expect(ctx[:age]).to eq(25)
    end

    it "checks presence via predicate" do
      expect(ctx.name?).to be true
      expect(ctx.missing?).to be false
    end

    it "responds to missing" do
      expect(ctx.respond_to?(:anything)).to be true
    end
  end

  describe "#merge!" do
    it "merges another hash into the context" do
      ctx = described_class.new(a: 1)
      ctx[:b] = 2
      ctx[:c] = 3
      expect(ctx.to_h).to eq(a: 1, b: 2, c: 3)
    end
  end

  describe "#freeze" do
    it "freezes the internal table" do
      ctx = described_class.new(a: 1)
      ctx.freeze
      expect(ctx).to be_frozen
      expect { ctx[:b] = 2 }.to raise_error(FrozenError)
    end
  end
end

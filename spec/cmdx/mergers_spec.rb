# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Mergers do
  subject(:mergers) { described_class.new }

  describe "#initialize" do
    it "registers the built-in merge strategies" do
      expect(mergers.registry.keys).to contain_exactly(
        :last_write_wins, :deep_merge, :no_merge
      )
      expect(mergers.lookup(:last_write_wins)).to be(CMDx::Mergers::LastWriteWins)
      expect(mergers.lookup(:deep_merge)).to be(CMDx::Mergers::DeepMerge)
      expect(mergers.lookup(:no_merge)).to be(CMDx::Mergers::NoMerge)
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      copy = mergers.dup
      copy.deregister(:no_merge)
      expect(mergers.registry).to have_key(:no_merge)
      expect(copy.registry).not_to have_key(:no_merge)
    end
  end

  describe "#register" do
    it "stores a callable" do
      c = ->(_ctx, _r) {}
      mergers.register(:custom, c)
      expect(mergers.lookup(:custom)).to be(c)
    end

    it "stores a block" do
      mergers.register(:b) { |_ctx, _r| nil }
      expect(mergers.lookup(:b)).to be_a(Proc)
    end

    it "raises when both a callable and block are given" do
      c = ->(_, _) {}
      expect { mergers.register(:x, c) { |_, _| nil } }
        .to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "raises when the handler does not respond to call" do
      expect { mergers.register(:x, Object.new) }
        .to raise_error(ArgumentError, /must respond to #call/)
    end
  end

  describe "#deregister" do
    it "removes a key" do
      mergers.deregister(:deep_merge)
      expect(mergers.registry).not_to have_key(:deep_merge)
    end
  end

  describe "#lookup" do
    it "raises on unknown keys" do
      expect { mergers.lookup(:bogus) }
        .to raise_error(ArgumentError, "unknown merge_strategy: :bogus")
    end
  end

  describe "#resolve" do
    it "defaults to :last_write_wins when spec is nil" do
      expect(mergers.resolve(nil)).to be(mergers.lookup(:last_write_wins))
    end

    it "looks up registered symbols" do
      expect(mergers.resolve(:deep_merge)).to be(mergers.lookup(:deep_merge))
    end

    it "passes through arbitrary callables" do
      c = ->(_ctx, _r) {}
      expect(mergers.resolve(c)).to be(c)
    end

    it "raises on unknown symbols" do
      expect { mergers.resolve(:bogus) }
        .to raise_error(ArgumentError, "unknown merge_strategy: :bogus")
    end
  end

  describe "built-in behavior" do
    let(:ctx) { CMDx::Context.build(a: 1, nested: { a: 1 }) }
    let(:result) { instance_double(CMDx::Result, context: CMDx::Context.build(b: 2, nested: { b: 2 })) }

    it ":last_write_wins shallow-merges" do
      mergers.lookup(:last_write_wins).call(ctx, result)
      expect(ctx.a).to eq(1)
      expect(ctx.b).to eq(2)
      expect(ctx.nested).to eq(b: 2)
    end

    it ":deep_merge recursively merges" do
      mergers.lookup(:deep_merge).call(ctx, result)
      expect(ctx.nested).to eq(a: 1, b: 2)
    end

    it ":no_merge leaves context untouched" do
      mergers.lookup(:no_merge).call(ctx, result)
      expect(ctx.a).to eq(1)
      expect(ctx.b).to be_nil
    end
  end

  describe "#empty? / #size" do
    it "reports the registry size" do
      expect(mergers.size).to eq(3)
      expect(mergers).not_to be_empty
    end
  end
end

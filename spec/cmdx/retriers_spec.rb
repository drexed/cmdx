# frozen_string_literal: true

RSpec.describe CMDx::Retriers do
  subject(:retriers) { described_class.new }

  describe "#initialize" do
    it "registers the built-in retry strategies" do
      expect(retriers.registry.keys).to contain_exactly(
        :exponential, :half_random, :full_random, :bounded_random,
        :linear, :fibonacci, :decorrelated_jitter
      )
      expect(retriers.lookup(:exponential)).to be(CMDx::Retriers::Exponential)
      expect(retriers.lookup(:half_random)).to be(CMDx::Retriers::HalfRandom)
      expect(retriers.lookup(:full_random)).to be(CMDx::Retriers::FullRandom)
      expect(retriers.lookup(:bounded_random)).to be(CMDx::Retriers::BoundedRandom)
      expect(retriers.lookup(:linear)).to be(CMDx::Retriers::Linear)
      expect(retriers.lookup(:fibonacci)).to be(CMDx::Retriers::Fibonacci)
      expect(retriers.lookup(:decorrelated_jitter)).to be(CMDx::Retriers::DecorrelatedJitter)
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      copy = retriers.dup
      copy.deregister(:exponential)
      expect(retriers.registry).to have_key(:exponential)
      expect(copy.registry).not_to have_key(:exponential)
    end
  end

  describe "#register" do
    it "stores a callable" do
      c = ->(_a, _d, _p) { 1.0 }
      retriers.register(:custom, c)
      expect(retriers.lookup(:custom)).to be(c)
    end

    it "stores a block" do
      retriers.register(:b) { |_a, _d, _p| 0.0 }
      expect(retriers.lookup(:b)).to be_a(Proc)
    end

    it "raises when both a callable and block are given" do
      c = ->(_, _, _) {}
      expect { retriers.register(:x, c) { |_, _, _| nil } }
        .to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "raises when the handler does not respond to call" do
      expect { retriers.register(:x, Object.new) }
        .to raise_error(ArgumentError, /must respond to #call/)
    end
  end

  describe "#deregister" do
    it "removes a key" do
      retriers.deregister(:exponential)
      expect(retriers.registry).not_to have_key(:exponential)
    end
  end

  describe "#key?" do
    it "reports membership" do
      expect(retriers.key?(:exponential)).to be(true)
      expect(retriers.key?(:bogus)).to be(false)
    end
  end

  describe "#lookup" do
    it "raises on unknown keys" do
      expect { retriers.lookup(:bogus) }
        .to raise_error(CMDx::UnknownEntryError, /unknown retrier :bogus/)
    end
  end

  describe "#resolve" do
    it "returns nil when spec is nil" do
      expect(retriers.resolve(nil)).to be_nil
    end

    it "looks up registered symbols" do
      expect(retriers.resolve(:linear)).to be(retriers.lookup(:linear))
    end

    it "passes through arbitrary callables" do
      c = ->(_a, _d, _p) { 0.0 }
      expect(retriers.resolve(c)).to be(c)
    end

    it "raises on unknown symbols" do
      expect { retriers.resolve(:bogus) }
        .to raise_error(CMDx::UnknownEntryError, /unknown retrier :bogus/)
    end

    it "raises on non-callable specs" do
      expect { retriers.resolve(Object.new) }
        .to raise_error(CMDx::UnknownEntryError, /unknown retrier/)
    end
  end

  describe "#empty? / #size" do
    it "reports the registry size" do
      expect(retriers.size).to eq(7)
      expect(retriers).not_to be_empty
    end
  end
end

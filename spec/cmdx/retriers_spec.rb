# frozen_string_literal: true

require "spec_helper"

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

  describe "built-in behavior" do
    it ":exponential doubles each attempt" do
      expect(retriers.lookup(:exponential).call(0, 0.5)).to eq(0.5)
      expect(retriers.lookup(:exponential).call(3, 0.5)).to eq(4.0)
    end

    it ":half_random samples within [delay/2, delay]" do
      strategy = retriers.lookup(:half_random)
      allow(strategy).to receive(:rand).and_return(0.0, 1.0)
      expect(strategy.call(0, 2.0)).to eq(1.0)
      expect(strategy.call(0, 2.0)).to eq(2.0)
    end

    it ":full_random samples within [0, delay]" do
      strategy = retriers.lookup(:full_random)
      allow(strategy).to receive(:rand).and_return(0.25)
      expect(strategy.call(0, 2.0)).to eq(0.5)
    end

    it ":bounded_random samples within [delay, 2*delay]" do
      strategy = retriers.lookup(:bounded_random)
      allow(strategy).to receive(:rand).and_return(0.5)
      expect(strategy.call(0, 2.0)).to eq(3.0)
    end

    it ":linear scales arithmetically" do
      expect(retriers.lookup(:linear).call(0, 1.0)).to eq(1.0)
      expect(retriers.lookup(:linear).call(3, 0.25)).to eq(1.0)
    end

    it ":fibonacci scales by the Fibonacci sequence" do
      strategy = retriers.lookup(:fibonacci)
      expect((0..5).map { |a| strategy.call(a, 1.0) })
        .to eq([1.0, 1.0, 2.0, 3.0, 5.0, 8.0])
    end

    it ":decorrelated_jitter falls back to base delay when prev is nil" do
      strategy = retriers.lookup(:decorrelated_jitter)
      allow(strategy).to receive(:rand).and_return(0.0, 1.0)
      expect(strategy.call(0, 1.0)).to eq(1.0)
      expect(strategy.call(0, 1.0)).to eq(3.0)
    end

    it ":decorrelated_jitter widens upper bound from prev_delay" do
      strategy = retriers.lookup(:decorrelated_jitter)
      allow(strategy).to receive(:rand).and_return(1.0)
      expect(strategy.call(0, 1.0, 4.0)).to eq(12.0)
    end
  end

  describe "#empty? / #size" do
    it "reports the registry size" do
      expect(retriers.size).to eq(7)
      expect(retriers).not_to be_empty
    end
  end
end

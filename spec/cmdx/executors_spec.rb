# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Executors do
  subject(:executors) { described_class.new }

  describe "#initialize" do
    it "registers the built-in executors" do
      expect(executors.registry.keys).to contain_exactly(:threads, :fibers)
      expect(executors.lookup(:threads)).to be(CMDx::Executors::Thread)
      expect(executors.lookup(:fibers)).to be(CMDx::Executors::Fiber)
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      copy = executors.dup
      copy.deregister(:threads)
      expect(executors.registry).to have_key(:threads)
      expect(copy.registry).not_to have_key(:threads)
    end
  end

  describe "#register" do
    it "stores a callable" do
      c = ->(jobs:, on_job:, **) { jobs.each { |j| on_job.call(j) } }
      executors.register(:custom, c)
      expect(executors.lookup(:custom)).to be(c)
    end

    it "stores a block" do
      executors.register(:b) { |jobs:, on_job:, **| jobs.each { |j| on_job.call(j) } }
      expect(executors.lookup(:b)).to be_a(Proc)
    end

    it "raises when both a callable and block are given" do
      c = ->(**) {}
      expect { executors.register(:x, c) { |**| nil } }
        .to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "raises when the handler does not respond to call" do
      expect { executors.register(:x, Object.new) }
        .to raise_error(ArgumentError, /must respond to #call/)
    end

    it "coerces string names to symbols" do
      c = ->(**) {}
      executors.register("custom", c)
      expect(executors.lookup(:custom)).to be(c)
    end
  end

  describe "#deregister" do
    it "removes a key" do
      executors.deregister(:threads)
      expect(executors.registry).not_to have_key(:threads)
    end
  end

  describe "#lookup" do
    it "raises on unknown keys" do
      expect { executors.lookup(:bogus) }.to raise_error(CMDx::UnknownEntryError, "unknown executor: :bogus")
    end
  end

  describe "#resolve" do
    it "defaults to :threads when spec is nil" do
      expect(executors.resolve(nil)).to be(CMDx::Executors::Thread)
    end

    it "looks up registered symbols" do
      expect(executors.resolve(:fibers)).to be(CMDx::Executors::Fiber)
    end

    it "passes through arbitrary callables" do
      c = ->(**) {}
      expect(executors.resolve(c)).to be(c)
    end

    it "raises on unknown symbols" do
      expect { executors.resolve(:bogus) }
        .to raise_error(CMDx::UnknownEntryError, "unknown executor: :bogus")
    end

    it "raises on non-callable, non-symbol values" do
      expect { executors.resolve(Object.new) }
        .to raise_error(CMDx::UnknownEntryError, /unknown executor/)
    end
  end

  describe "#empty? / #size" do
    it "reports the registry size" do
      expect(executors.size).to eq(2)
      expect(executors).not_to be_empty
    end
  end
end

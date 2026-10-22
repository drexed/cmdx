# frozen_string_literal: true

RSpec.describe CMDx::Limiters do
  subject(:limiters) { described_class.new }

  describe "#initialize" do
    it "registers the built-in limiter strategies" do
      expect(limiters.registry.keys).to contain_exactly(:fixed_window, :leaky_bucket)
      expect(limiters.lookup(:fixed_window)).to be(CMDx::Limiters::FixedWindow)
      expect(limiters.lookup(:leaky_bucket)).to be(CMDx::Limiters::LeakyBucket)
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      copy = limiters.dup
      copy.deregister(:fixed_window)

      expect(limiters.registry).to have_key(:fixed_window)
      expect(copy.registry).not_to have_key(:fixed_window)
    end
  end

  describe "#register" do
    it "stores a callable" do
      callable = ->(_quota) {}
      limiters.register(:custom, callable)

      expect(limiters.lookup(:custom)).to be(callable)
    end

    it "stores a block" do
      limiters.register(:block_limiter) { |_quota| nil }

      expect(limiters.lookup(:block_limiter)).to be_a(Proc)
    end

    it "coerces the name to a symbol" do
      limiters.register("custom", ->(_quota) {})

      expect(limiters.lookup(:custom)).to be_a(Proc)
    end

    it "returns self for chaining" do
      expect(limiters.register(:x, ->(_quota) {})).to be(limiters)
    end

    it "raises when both a callable and block are given" do
      callable = ->(_quota) {}
      expect { limiters.register(:x, callable) { |_quota| nil } }
        .to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "raises when the handler does not respond to call" do
      expect { limiters.register(:x, Object.new) }
        .to raise_error(ArgumentError, /must respond to #call/)
    end
  end

  describe "#deregister" do
    it "removes a key" do
      limiters.deregister(:fixed_window)

      expect(limiters.registry).not_to have_key(:fixed_window)
    end
  end

  describe "#key?" do
    it "reports membership" do
      expect(limiters.key?(:fixed_window)).to be(true)
      expect(limiters.key?(:bogus)).to be(false)
    end
  end

  describe "#lookup" do
    it "raises on unknown keys" do
      expect { limiters.lookup(:bogus) }
        .to raise_error(CMDx::UnknownEntryError, /unknown limiter :bogus/)
    end
  end

  describe "#resolve" do
    it "returns nil when spec is nil" do
      expect(limiters.resolve(nil)).to be_nil
    end

    it "looks up registered symbols" do
      expect(limiters.resolve(:fixed_window)).to be(limiters.lookup(:fixed_window))
    end

    it "passes through arbitrary callables" do
      callable = ->(_quota) {}
      expect(limiters.resolve(callable)).to be(callable)
    end

    it "raises on unknown symbols" do
      expect { limiters.resolve(:bogus) }
        .to raise_error(CMDx::UnknownEntryError, /unknown limiter :bogus/)
    end

    it "raises on non-callable specs" do
      expect { limiters.resolve(Object.new) }
        .to raise_error(CMDx::UnknownEntryError, /unknown limiter/)
    end
  end

  describe "#empty? / #size" do
    it "reports the registry size" do
      expect(limiters.size).to eq(2)
      expect(limiters).not_to be_empty
    end
  end
end

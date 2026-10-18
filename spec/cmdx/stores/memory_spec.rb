# frozen_string_literal: true

RSpec.describe CMDx::Stores::Memory do
  subject(:store) { described_class.new }

  describe "#get" do
    it "returns nil for a missing key" do
      expect(store.get(:missing)).to be_nil
    end

    it "returns the stored string value" do
      store.set(:k, "v")

      expect(store.get(:k)).to eq("v")
    end

    it "coerces symbol keys to strings" do
      store.set("k", "v")

      expect(store.get(:k)).to eq("v")
    end

    it "returns nil after the TTL elapses" do
      store.set(:k, "v", ttl: 1)

      sleep 1.1

      expect(store.get(:k)).to be_nil
    end
  end

  describe "#set" do
    it "returns true on unconditional set" do
      expect(store.set(:k, "a")).to be(true)
      expect(store.get(:k)).to eq("a")
    end

    it "returns false when nx is set and the key exists" do
      store.set(:k, "a")

      expect(store.set(:k, "b", nx: true)).to be(false)
      expect(store.get(:k)).to eq("a")
    end

    it "returns true when nx is set and the key is absent" do
      expect(store.set(:k, "a", nx: true)).to be(true)
    end

    it "returns false when xx is set and the key is absent" do
      expect(store.set(:k, "a", xx: true)).to be(false)
    end

    it "returns true when xx is set and the key exists" do
      store.set(:k, "a")

      expect(store.set(:k, "b", xx: true)).to be(true)
      expect(store.get(:k)).to eq("b")
    end

    it "raises when nx and xx are both true" do
      expect { store.set(:k, "v", nx: true, xx: true) }
        .to raise_error(ArgumentError, /nx and xx/)
    end

    it "raises when ttl is zero" do
      expect { store.set(:k, "v", ttl: 0) }
        .to raise_error(ArgumentError, /positive Integer/)
    end
  end

  describe "#incr" do
    it "starts at 1 for a missing key" do
      expect(store.incr(:n)).to eq(1)
      expect(store.get(:n)).to eq("1")
    end

    it "increments an existing counter" do
      store.incr(:n)
      store.incr(:n)

      expect(store.incr(:n)).to eq(3)
    end

    it "expires the counter after the ttl elapses" do
      store.incr(:n, ttl: 1)

      sleep 1.1

      expect(store.get(:n)).to be_nil
      expect(store.incr(:n)).to eq(1)
    end

    it "refreshes ttl on every increment when ttl is set" do
      store.incr(:n, ttl: 2)
      sleep 1.1
      store.incr(:n, ttl: 2)

      sleep 1.1

      expect(store.get(:n)).not_to be_nil

      sleep 1.1

      expect(store.get(:n)).to be_nil
    end
  end

  describe "#ttl" do
    it "returns nil for a missing key" do
      expect(store.ttl(:missing)).to be_nil
    end

    it "returns remaining seconds for a key with expiry" do
      store.set(:k, "v", ttl: 30)

      expect(store.ttl(:k)).to be_between(1, 30)
    end
  end

  describe "#decr" do
    it "returns 0 for a missing key" do
      expect(store.decr(:n)).to eq(0)
    end

    it "decrements an existing counter and removes the key at zero" do
      store.incr(:n)
      store.incr(:n)

      expect(store.decr(:n)).to eq(1)
      expect(store.decr(:n)).to eq(0)
      expect(store.get(:n)).to be_nil
    end
  end

  describe "#del" do
    it "returns 0 when the key is missing" do
      expect(store.del(:k)).to eq(0)
    end

    it "returns 1 and removes the key" do
      store.set(:k, "v")

      expect(store.del(:k)).to eq(1)
      expect(store.get(:k)).to be_nil
    end
  end
end

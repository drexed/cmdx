# frozen_string_literal: true

RSpec.describe CMDx::Stores::Redis do
  subject(:store) { described_class.new(redis:, namespace: "cmdx:test") }

  let(:redis) { CMDx::Testing::FakeRedis.new }

  describe "#get" do
    it "prefixes keys with the namespace" do
      redis.set("cmdx:test:token", "abc")

      expect(store.get(:token)).to eq("abc")
    end
  end

  describe "#set" do
    it "writes through the client with a namespace prefix" do
      store.set(:token, "abc")

      expect(redis.get("cmdx:test:token")).to eq("abc")
    end

    it "passes nx and ttl to the client" do
      expect(store.set(:token, "a", nx: true, ttl: 60)).to be(true)
      expect(store.set(:token, "b", nx: true, ttl: 60)).to be(false)
      expect(redis.ttl["cmdx:test:token"]).to eq(60)
    end
  end

  describe "#incr" do
    it "increments via the client and sets ttl on the first count" do
      expect(store.incr(:hits, ttl: 30)).to eq(1)
      expect(store.incr(:hits)).to eq(2)
      expect(redis.ttl["cmdx:test:hits"]).to eq(30)
    end
  end

  describe "#del" do
    it "deletes the prefixed key" do
      store.set(:token, "x")

      expect(store.del(:token)).to eq(1)
      expect(store.get(:token)).to be_nil
    end
  end
end

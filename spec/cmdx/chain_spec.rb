# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Chain do
  subject(:chain) { described_class.new }

  let(:task_class) { create_task_class(name: "ChainSampleTask") }
  let(:task) { task_class.new }

  def build_result(signal = CMDx::Signal.success, **opts)
    CMDx::Result.new(chain, task, signal, **opts)
  end

  after { described_class.clear }

  describe ".current" do
    it "returns nil when nothing is stored" do
      expect(described_class.current).to be_nil
    end

    it "reads the chain from fiber-local storage" do
      described_class.current = chain
      expect(described_class.current).to be(chain)
    end
  end

  describe ".current=" do
    it "writes to fiber-local storage" do
      described_class.current = chain

      expect(Fiber[described_class::STORAGE_KEY]).to be(chain)
    end

    it "does not leak writes from child fibers to the parent" do
      described_class.current = chain

      Fiber.new { described_class.current = described_class.new }.resume

      expect(described_class.current).to be(chain)
    end
  end

  describe ".clear" do
    it "nils out fiber-local storage" do
      described_class.current = chain
      described_class.clear

      expect(described_class.current).to be_nil
    end
  end

  describe "#initialize" do
    it "assigns a UUIDv7 id" do
      expect(chain.id).to match(/\A\h{8}-\h{4}-7\h{3}-\h{4}-\h{12}\z/)
    end

    it "starts with an empty results array" do
      expect(chain.results).to eq([])
      expect(chain).to be_empty
    end

    it "generates a unique id per instance" do
      expect(chain.id).not_to eq(described_class.new.id)
    end

    it "defaults xid to nil" do
      expect(chain.xid).to be_nil
    end

    it "stores an explicit xid" do
      expect(described_class.new("req-123").xid).to eq("req-123")
    end
  end

  describe "#push" do
    it "appends the result and returns self" do
      result = Object.new

      expect(chain.push(result)).to be(chain)
      expect(chain.results).to eq([result])
    end

    it "is aliased as <<" do
      result = Object.new
      chain << result

      expect(chain.results).to eq([result])
    end

    it "preserves insertion order" do
      a = Object.new
      b = Object.new
      c = Object.new
      chain.push(a).push(b).push(c)

      expect(chain.results).to eq([a, b, c])
    end

    it "is safe under concurrent pushes" do
      threads = Array.new(10) do |i|
        Thread.new { 20.times { |j| chain.push([i, j]) } }
      end
      threads.each(&:join)

      expect(chain.results.size).to eq(200)
    end
  end

  describe "#unshift" do
    it "prepends the result and returns self" do
      result = Object.new

      expect(chain.unshift(result)).to be(chain)
      expect(chain.results).to eq([result])
    end

    it "places the new result before existing ones" do
      a = Object.new
      b = Object.new
      chain.push(a)
      chain.unshift(b)

      expect(chain.results).to eq([b, a])
    end

    it "is safe under concurrent unshifts" do
      threads = Array.new(10) do |i|
        Thread.new { 20.times { |j| chain.unshift([i, j]) } }
      end
      threads.each(&:join)

      expect(chain.results.size).to eq(200)
    end
  end

  describe "#root" do
    it "returns the result flagged as root" do
      non_root = build_result
      root     = build_result(root: true)
      chain.push(non_root).push(root)

      expect(chain.root).to be(root)
    end

    it "returns nil when no root is present" do
      chain.push(build_result)

      expect(chain.root).to be_nil
    end

    it "returns nil for an empty chain" do
      expect(chain.root).to be_nil
    end

    it "returns the first root when multiple are present" do
      first  = build_result(root: true)
      second = build_result(root: true)
      chain.push(first).push(second)

      expect(chain.root).to be(first)
    end
  end

  describe "#state" do
    it "returns the state of the root result" do
      chain.push(build_result(CMDx::Signal.success, root: true))

      expect(chain.state).to eq(CMDx::Signal::COMPLETE)
    end

    it "returns nil when no root exists" do
      chain.push(build_result)

      expect(chain.state).to be_nil
    end

    it "returns nil for an empty chain" do
      expect(chain.state).to be_nil
    end
  end

  describe "#status" do
    it "returns the status of the root result" do
      chain.push(build_result(CMDx::Signal.success, root: true))

      expect(chain.status).to eq(CMDx::Signal::SUCCESS)
    end

    it "returns nil when no root exists" do
      chain.push(build_result)

      expect(chain.status).to be_nil
    end

    it "returns nil for an empty chain" do
      expect(chain.status).to be_nil
    end
  end

  describe "#index" do
    it "returns the position of a known result" do
      a = Object.new
      b = Object.new
      chain.push(a).push(b)

      expect(chain.index(a)).to eq(0)
      expect(chain.index(b)).to eq(1)
    end

    it "returns nil when the result is absent" do
      expect(chain.index(Object.new)).to be_nil
    end
  end

  describe "#empty?" do
    it "is true for a fresh chain" do
      expect(chain).to be_empty
    end

    it "is false once a result is pushed" do
      chain.push(Object.new)
      expect(chain).not_to be_empty
    end
  end

  describe "#size" do
    it "returns the number of results" do
      expect(chain.size).to eq(0)
      chain.push(Object.new).push(Object.new)
      expect(chain.size).to eq(2)
    end
  end

  describe "#each" do
    it "yields each result in insertion order" do
      a = Object.new
      b = Object.new
      chain.push(a).push(b)

      yielded = []
      chain.each { |r| yielded << r } # rubocop:disable Style/MapIntoArray

      expect(yielded).to eq([a, b])
    end

    it "returns an Enumerator without a block" do
      chain.push(:a).push(:b)

      expect(chain.each).to be_a(Enumerator)
      expect(chain.each.to_a).to eq(%i[a b])
    end
  end

  describe "#freeze" do
    it "freezes the chain and returns self" do
      expect(chain.freeze).to be(chain)
      expect(chain).to be_frozen
    end

    it "freezes the underlying results array" do
      chain.push(Object.new)
      chain.freeze

      expect(chain.results).to be_frozen
    end

    it "prevents further mutation via push" do
      chain.freeze

      expect { chain.push(Object.new) }.to raise_error(FrozenError)
    end

    it "prevents further mutation via unshift" do
      chain.freeze

      expect { chain.unshift(Object.new) }.to raise_error(FrozenError)
    end
  end
end


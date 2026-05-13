# frozen_string_literal: true

RSpec.describe CMDx::Util do
  let(:receiver) do
    Class.new do
      def truthy = true # rubocop:disable Naming/PredicateMethod
      def falsy = false # rubocop:disable Naming/PredicateMethod
      def shout(word) = word.upcase
    end.new
  end

  describe ".evaluate" do
    context "with booleans and nil" do
      it "returns false for nil" do
        expect(described_class.evaluate(nil, receiver)).to be(false)
      end

      it "returns false for false" do
        expect(described_class.evaluate(false, receiver)).to be(false)
      end

      it "returns true for true" do
        expect(described_class.evaluate(true, receiver)).to be(true)
      end
    end

    context "with a Symbol" do
      it "sends the method on the receiver" do
        expect(described_class.evaluate(:truthy, receiver)).to be(true)
      end

      it "forwards additional arguments" do
        expect(described_class.evaluate(:shout, receiver, "hi")).to eq("HI")
      end
    end

    context "with a Proc" do
      it "runs the proc via instance_exec on the receiver" do
        probe = proc { truthy }
        expect(described_class.evaluate(probe, receiver)).to be(true)
      end

      it "forwards args and sets self to the receiver" do
        probe = proc { |word| shout(word) }
        expect(described_class.evaluate(probe, receiver, "hi")).to eq("HI")
      end
    end

    context "with a callable object" do
      it "invokes #call with the receiver and args" do
        callable = Class.new do
          def self.call(receiver, word)
            receiver.shout(word)
          end
        end

        expect(described_class.evaluate(callable, receiver, "hi")).to eq("HI")
      end
    end

    context "with an unsupported condition" do
      it "raises ArgumentError" do
        expect { described_class.evaluate(123, receiver) }
          .to raise_error(ArgumentError, /condition must be a Symbol, Proc, or respond to #call/)
      end
    end
  end

  describe ".if?" do
    it "returns true when condition is nil" do
      expect(described_class.if?(nil, receiver)).to be(true)
    end

    it "delegates to evaluate otherwise" do
      expect(described_class.if?(:truthy, receiver)).to be(true)
      expect(described_class.if?(:falsy, receiver)).to be(false)
    end
  end

  describe ".unless?" do
    it "returns true when condition is nil" do
      expect(described_class.unless?(nil, receiver)).to be(true)
    end

    it "returns the negation of evaluate" do
      expect(described_class.unless?(:truthy, receiver)).to be(false)
      expect(described_class.unless?(:falsy, receiver)).to be(true)
    end
  end

  describe ".satisfied?" do
    it "is true when if? is true and unless? is true" do
      expect(described_class.satisfied?(:truthy, :falsy, receiver)).to be(true)
    end

    it "is false when the if condition fails" do
      expect(described_class.satisfied?(:falsy, :falsy, receiver)).to be(false)
    end

    it "is false when the unless condition is truthy" do
      expect(described_class.satisfied?(:truthy, :truthy, receiver)).to be(false)
    end

    it "is true when both conditions are nil" do
      expect(described_class.satisfied?(nil, nil, receiver)).to be(true)
    end
  end

  describe ".deep_merge" do
    it "merges nested hashes with last-write-wins for scalars" do
      left = { a: 1, b: { c: 2, d: 3 } }
      right = { b: { d: 4, e: 5 } }
      expect(described_class.deep_merge(left, right)).to eq(a: 1, b: { c: 2, d: 4, e: 5 })
    end

    it "returns rhs when either side is not a Hash" do
      expect(described_class.deep_merge({}, "x")).to eq("x")
      expect(described_class.deep_merge("x", {})).to eq({})
    end
  end

  describe ".deep_dup" do
    it "duplicates nested hashes and arrays independently" do
      tree = { a: { b: [1, 2] } }
      copy = described_class.deep_dup(tree)
      copy[:a][:b] << 3
      expect(tree[:a][:b]).to eq([1, 2])
      expect(copy[:a][:b]).to eq([1, 2, 3])
    end

    it "shares immutable scalars" do
      tree = { n: 1, s: :x, t: true, f: false, z: nil }
      expect(described_class.deep_dup(tree)).to eq(n: 1, s: :x, t: true, f: false, z: nil)
    end

    it "returns the original when dup raises" do
      unduppable = Class.new { def dup = raise "nope" }.new
      expect(described_class.deep_dup(val: unduppable)[:val]).to be(unduppable)
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Callable do
  describe ".wrap" do
    it "returns symbols as-is" do
      expect(described_class.wrap(:my_method)).to eq(:my_method)
    end

    it "returns procs as-is" do
      prc = -> { 42 }
      expect(described_class.wrap(prc)).to equal(prc)
    end

    it "wraps a class into a proc" do
      klass = Class.new do
        def call(x)
          x * 2
        end
      end

      wrapped = described_class.wrap(klass)
      expect(wrapped).to be_a(Proc)
      expect(wrapped.call(5)).to eq(10)
    end

    it "wraps a callable instance" do
      obj = Object.new
      def obj.call(x); x + 1; end

      wrapped = described_class.wrap(obj)
      expect(wrapped.call(4)).to eq(5)
    end
  end

  describe ".resolve" do
    it "resolves a symbol as a method on receiver" do
      receiver = Object.new
      def receiver.greet; "hello"; end

      expect(described_class.resolve(:greet, receiver)).to eq("hello")
    end

    it "resolves a proc" do
      expect(described_class.resolve(-> { 42 }, nil)).to eq(42)
    end

    it "resolves a callable object" do
      obj = Object.new
      def obj.call; "called"; end

      expect(described_class.resolve(obj, nil)).to eq("called")
    end
  end

  describe ".evaluate" do
    it "returns true for nil condition" do
      expect(described_class.evaluate(nil, nil)).to be(true)
    end

    it "evaluates a proc condition" do
      expect(described_class.evaluate(-> { true }, nil)).to be(true)
      expect(described_class.evaluate(-> { false }, nil)).to be(false)
    end

    it "evaluates a symbol condition" do
      receiver = Object.new
      def receiver.active?; true; end

      expect(described_class.evaluate(:active?, receiver)).to be(true)
    end
  end
end

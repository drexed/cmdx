# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::CoercionRegistry do
  describe "#resolve" do
    it "returns built-in coercion modules" do
      reg = described_class.new
      expect(reg.resolve(:string)).to eq(CMDx::Coercions::String)
      expect(reg.resolve(:integer)).to eq(CMDx::Coercions::Integer)
    end

    it "returns a Class or Module unchanged" do
      reg = described_class.new
      mod = CMDx::Coercions::Hash
      expect(reg.resolve(mod)).to be(mod)
    end

    it "raises UnknownCoercionError for unknown types" do
      reg = described_class.new
      expect { reg.resolve(:not_registered) }.to raise_error(CMDx::UnknownCoercionError)
    end
  end

  describe "#register" do
    it "adds a custom coercion" do
      reg = described_class.new
      klass = Class.new do
        def self.call(value)
          "coerced:#{value}"
        end
      end

      reg.register(:widget, klass)
      expect(reg.resolve(:widget)).to be(klass)
      expect(klass.call(1)).to eq("coerced:1")
    end
  end

  describe "#for_child" do
    it "duplicates the registry for copy-on-write" do
      parent = described_class.new
      parent.register(:widget, CMDx::Coercions::String)

      child = parent.for_child
      child.register(:other, CMDx::Coercions::Integer)

      expect(parent.registry.key?(:other)).to be(false)
      expect(child.registry.key?(:other)).to be(true)
      expect(parent.resolve(:widget)).to eq(CMDx::Coercions::String)
      expect(child.resolve(:widget)).to eq(CMDx::Coercions::String)
    end
  end
end

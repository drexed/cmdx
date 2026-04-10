# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ValidatorRegistry do
  describe "#resolve" do
    it "returns built-in validators" do
      reg = described_class.new
      expect(reg.resolve(:presence)).to eq(CMDx::Validators::Presence)
      expect(reg.resolve(:format)).to eq(CMDx::Validators::Format)
    end

    it "raises UnknownValidatorError for unknown types" do
      reg = described_class.new
      expect { reg.resolve(:not_a_validator) }.to raise_error(CMDx::UnknownValidatorError, /unknown validator/)
    end
  end

  describe "#register" do
    it "adds a custom validator" do
      reg = described_class.new
      klass = Class.new do
        def self.call(_value, **)
          "invalid"
        end
      end

      reg.register(:always_bad, klass)
      expect(reg.resolve(:always_bad)).to be(klass)
      expect(klass.call(nil)).to eq("invalid")
    end
  end

  describe "#for_child" do
    it "duplicates the registry for copy-on-write" do
      parent = described_class.new
      parent.register(:custom, CMDx::Validators::Length)

      child = parent.for_child
      child.register(:other, CMDx::Validators::Numeric)

      expect(parent.registry.key?(:other)).to be(false)
      expect(child.registry.key?(:other)).to be(true)
    end
  end
end

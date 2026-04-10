# frozen_string_literal: true

require "spec_helper"

module CmdxMiddlewareRegistrySpecFixtures

  module OuterMw

    def self.call(task, *, &)
      task.context[:trace] ||= []
      task.context[:trace] << :outer_before
      yield
      task.context[:trace] << :outer_after
    end

  end

  module InnerMw

    def self.call(task, *, &)
      task.context[:trace] ||= []
      task.context[:trace] << :inner_before
      yield
      task.context[:trace] << :inner_after
    end

  end

  module NoYieldMw

    def self.call(_task, *)
      # intentionally does not yield
    end

  end

end

RSpec.describe CMDx::MiddlewareRegistry do
  let(:registry) { described_class.new }

  let(:task_class) do
    Class.new(CMDx::Task) do
      def work
        context[:ran] = true
      end
    end
  end

  let(:task) do
    t = task_class.allocate
    t.instance_variable_set(:@context, CMDx::Context.new)
    t
  end

  describe "#register and #deregister" do
    it "adds and removes middleware entries" do
      registry.register(CmdxMiddlewareRegistrySpecFixtures::OuterMw)
      expect(registry.stack.size).to eq(1)
      registry.deregister(CmdxMiddlewareRegistrySpecFixtures::OuterMw)
      expect(registry.stack).to be_empty
    end
  end

  describe "#call" do
    it "returns the block value when the stack is empty" do
      expect(registry.call(task) { 42 }).to eq(42)
    end

    it "wraps execution in an onion chain (outer registered first)" do
      registry.register(CmdxMiddlewareRegistrySpecFixtures::OuterMw)
      registry.register(CmdxMiddlewareRegistrySpecFixtures::InnerMw)

      registry.call(task) { task.context[:inner] = true }

      expect(task.context[:inner]).to be(true)
      expect(task.context[:trace]).to eq(%i[outer_before inner_before inner_after outer_after])
    end

    it "raises MiddlewareError when middleware does not yield" do
      registry.register(CmdxMiddlewareRegistrySpecFixtures::NoYieldMw)
      expect { registry.call(task) { :ok } }.to raise_error(CMDx::MiddlewareError, /did not yield/)
    end
  end

  describe "#any?" do
    it "reflects whether middleware is registered" do
      expect(registry.any?).to be(false)
      registry.register(CmdxMiddlewareRegistrySpecFixtures::OuterMw)
      expect(registry.any?).to be(true)
    end
  end

  describe "#for_child" do
    it "duplicates the stack for copy-on-write" do
      registry.register(CmdxMiddlewareRegistrySpecFixtures::OuterMw)
      child = registry.for_child
      child.register(CmdxMiddlewareRegistrySpecFixtures::InnerMw)

      expect(registry.stack.size).to eq(1)
      expect(child.stack.size).to eq(2)
    end
  end
end

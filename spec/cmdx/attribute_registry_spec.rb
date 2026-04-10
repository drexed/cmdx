# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::AttributeRegistry do
  let(:registry) { described_class.new }

  describe "#register, #deregister, and #[]" do
    it "registers, looks up, and removes attributes" do
      attr = CMDx::Attribute.new(:email, :string, required: true)
      registry.register(attr)

      expect(registry[:email]).to be(attr)
      registry.deregister(:email)
      expect(registry[:email]).to be_nil
    end
  end

  describe "#define_readers!" do
    it "defines accessors that read from @_attributes" do
      attr = CMDx::Attribute.new(:email, :string, required: false)
      registry.register(attr)

      host = Class.new
      registry.define_readers!(host)
      instance = host.new
      instance.instance_variable_set(:@_attributes, { email: "a@b.c" })

      expect(instance.email).to eq("a@b.c")
    end
  end

  describe "#resolve" do
    let(:task_class) { Class.new(CMDx::Task) { def work; end } }
    let(:task) { task_class.allocate }

    it "resolves values and runs validations" do
      registry.register(CMDx::Attribute.new(:email, :string, required: true))
      errors = CMDx::Errors.new

      empty_ctx = CMDx::Context.new({})
      registry.resolve(task, empty_ctx, errors)
      expect(errors.any?).to be(true)

      errors.clear
      good_ctx = CMDx::Context.new(email: "x")
      resolved = registry.resolve(task, good_ctx, errors)
      expect(errors).to be_empty
      expect(resolved[:email]).to eq("x")
    end
  end

  describe "#schema" do
    it "returns a hash representation of attributes" do
      registry.register(CMDx::Attribute.new(:name, :string, required: false, default: "anon"))
      expect(registry.schema[:name]).to include(name: :name, type: :string, required: false)
    end
  end

  describe "#for_child" do
    it "duplicates definitions without sharing attribute objects" do
      attr = CMDx::Attribute.new(:n, nil, required: false)
      registry.register(attr)

      child = registry.for_child
      expect(child[:n]).not_to be(attr)
      expect(child[:n].name).to eq(:n)

      child.register(CMDx::Attribute.new(:other, nil, required: false))
      expect(registry[:other]).to be_nil
      expect(child[:other]).to be_a(CMDx::Attribute)
    end
  end
end

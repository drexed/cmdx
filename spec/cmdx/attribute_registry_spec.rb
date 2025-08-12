# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::AttributeRegistry do
  let(:attribute1) { instance_double(CMDx::Attribute) }
  let(:attribute2) { instance_double(CMDx::Attribute) }
  let(:initial_registry) { [attribute1] }
  let(:task) { instance_double(CMDx::Task) }

  describe "#initialize" do
    context "without arguments" do
      subject(:registry) { described_class.new }

      it "initializes with empty registry" do
        expect(registry.registry).to eq([])
      end
    end

    context "with initial registry" do
      subject(:registry) { described_class.new(initial_registry) }

      it "initializes with provided registry" do
        expect(registry.registry).to eq(initial_registry)
      end
    end
  end

  describe "#registry" do
    subject(:registry) { described_class.new(initial_registry) }

    it "returns the internal registry array" do
      expect(registry.registry).to eq(initial_registry)
    end
  end

  describe "#to_a" do
    subject(:registry) { described_class.new(initial_registry) }

    it "aliases to registry method" do
      expect(registry.to_a).to eq(registry.registry)
      expect(registry.to_a).to eq(initial_registry)
    end
  end

  describe "#dup" do
    subject(:registry) { described_class.new(initial_registry) }

    let(:duplicated_registry) { registry.dup }

    it "creates new instance with duplicated registry" do
      expect(duplicated_registry).to be_a(described_class)
      expect(duplicated_registry).not_to be(registry)
      expect(duplicated_registry.registry).to eq(registry.registry)
      expect(duplicated_registry.registry).not_to be(registry.registry)
    end

    it "maintains independence between original and duplicate" do
      new_attribute = instance_double(CMDx::Attribute)

      duplicated_registry.register(new_attribute)

      expect(duplicated_registry.registry).to include(new_attribute)
      expect(registry.registry).not_to include(new_attribute)
    end
  end

  describe "#register" do
    subject(:registry) { described_class.new }

    context "with single attribute" do
      it "adds attribute to registry and returns self" do
        result = registry.register(attribute1)

        expect(registry.registry).to include(attribute1)
        expect(result).to be(registry)
      end
    end

    context "with multiple attributes as array" do
      let(:attributes) { [attribute1, attribute2] }

      it "adds all attributes to registry" do
        registry.register(attributes)

        expect(registry.registry).to include(attribute1)
        expect(registry.registry).to include(attribute2)
        expect(registry.registry.size).to eq(2)
      end
    end

    context "with non-array attribute" do
      it "converts to array and adds to registry" do
        registry.register(attribute1)

        expect(registry.registry).to eq([attribute1])
      end
    end

    context "when adding to existing registry" do
      subject(:registry) { described_class.new(initial_registry) }

      it "appends new attributes to existing ones" do
        registry.register(attribute2)

        expect(registry.registry).to eq([attribute1, attribute2])
        expect(registry.registry.size).to eq(2)
      end
    end

    context "with empty array" do
      it "does not modify registry" do
        original_size = registry.registry.size

        registry.register([])

        expect(registry.registry.size).to eq(original_size)
      end
    end
  end

  describe "#define_and_verify" do
    subject(:registry) { described_class.new([attribute1, attribute2]) }

    it "sets task on each attribute and calls define_and_verify_tree" do
      expect(attribute1).to receive(:task=).with(task)
      expect(attribute2).to receive(:task=).with(task)
      expect(attribute1).to receive(:define_and_verify_tree)
      expect(attribute2).to receive(:define_and_verify_tree)

      registry.define_and_verify(task)
    end

    context "with empty registry" do
      subject(:registry) { described_class.new([]) }

      it "does not call any methods" do
        expect { registry.define_and_verify(task) }.not_to raise_error
      end
    end

    context "when attribute raises error" do
      before do
        allow(attribute1).to receive(:task=)
        allow(attribute1).to receive(:define_and_verify_tree).and_raise(StandardError, "attribute error")
      end

      it "propagates the error" do
        expect { registry.define_and_verify(task) }.to raise_error(StandardError, "attribute error")
      end
    end
  end
end

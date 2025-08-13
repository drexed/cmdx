# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::AttributeRegistry, type: :unit do
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

  describe "#deregister" do
    subject(:registry) { described_class.new([parent_attribute, other_attribute]) }

    let(:child_attribute) { instance_double(CMDx::Attribute, method_name: :child_attr, children: []) }
    let(:parent_attribute) { instance_double(CMDx::Attribute, method_name: :parent_attr, children: [child_attribute]) }
    let(:other_attribute) { instance_double(CMDx::Attribute, method_name: :other_attr, children: []) }

    context "with single attribute name" do
      it "removes attribute by method_name and returns self" do
        result = registry.deregister(:parent_attr)

        expect(registry.registry).not_to include(parent_attribute)
        expect(registry.registry).to include(other_attribute)
        expect(result).to be(registry)
      end

      it "converts string names to symbols" do
        registry.deregister("parent_attr")

        expect(registry.registry).not_to include(parent_attribute)
        expect(registry.registry).to include(other_attribute)
      end
    end

    context "with multiple attribute names" do
      it "handles array of names" do
        registry.deregister(%i[parent_attr other_attr])

        expect(registry.registry).to be_empty
      end
    end

    context "with child attribute name" do
      it "removes parent attribute when child matches" do
        registry.deregister(:child_attr)

        expect(registry.registry).not_to include(parent_attribute)
        expect(registry.registry).to include(other_attribute)
      end
    end

    context "with non-existent attribute name" do
      it "does not modify registry" do
        original_registry = registry.registry.dup

        registry.deregister(:non_existent)

        expect(registry.registry).to eq(original_registry)
      end
    end

    context "with nested children" do
      subject(:registry) { described_class.new([complex_parent, other_attribute]) }

      let(:grandchild_attribute) { instance_double(CMDx::Attribute, method_name: :grandchild_attr, children: []) }
      let(:child_with_children) { instance_double(CMDx::Attribute, method_name: :child_with_children, children: [grandchild_attribute]) }
      let(:complex_parent) { instance_double(CMDx::Attribute, method_name: :complex_parent, children: [child_with_children]) }

      it "removes parent when deeply nested child matches" do
        registry.deregister(:grandchild_attr)

        expect(registry.registry).not_to include(complex_parent)
        expect(registry.registry).to include(other_attribute)
      end
    end

    context "with empty registry" do
      subject(:registry) { described_class.new([]) }

      it "does not raise error" do
        expect { registry.deregister(:any_name) }.not_to raise_error
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

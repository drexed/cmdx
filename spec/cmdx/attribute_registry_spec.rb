# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::AttributeRegistry do
  subject(:registry) { described_class.new(initial_registry) }

  let(:initial_registry) { [] }
  let(:mock_attribute) { instance_double(CMDx::Attribute) }
  let(:mock_task) { instance_double(CMDx::Task) }

  describe "#initialize" do
    context "when no registry is provided" do
      subject(:registry) { described_class.new }

      it "initializes with an empty array" do
        expect(registry.registry).to eq([])
      end
    end

    context "when a registry is provided" do
      let(:initial_registry) { [mock_attribute] }

      it "initializes with the provided registry" do
        expect(registry.registry).to eq([mock_attribute])
      end
    end
  end

  describe "#registry" do
    let(:initial_registry) { [mock_attribute] }

    it "returns the internal registry array" do
      expect(registry.registry).to eq([mock_attribute])
    end
  end

  describe "#to_a" do
    let(:initial_registry) { [mock_attribute] }

    it "returns the registry array" do
      expect(registry.to_a).to eq([mock_attribute])
    end

    it "is an alias for registry" do
      expect(registry.method(:to_a)).to eq(registry.method(:registry))
    end
  end

  describe "#dup" do
    let(:initial_registry) { [mock_attribute] }

    it "returns a new AttributeRegistry instance" do
      duplicated = registry.dup

      expect(duplicated).to be_a(described_class)
      expect(duplicated).not_to be(registry)
    end

    it "duplicates the registry array" do
      duplicated = registry.dup

      expect(duplicated.registry).to eq(registry.registry)
      expect(duplicated.registry).not_to be(registry.registry)
    end

    it "allows independent modification of the duplicated registry" do
      duplicated = registry.dup
      new_attribute = instance_double(CMDx::Attribute)

      duplicated.register(new_attribute)

      expect(duplicated.registry).to include(new_attribute)
      expect(registry.registry).not_to include(new_attribute)
    end
  end

  describe "#register" do
    context "when registering a single attribute" do
      it "adds the attribute to the registry" do
        registry.register(mock_attribute)

        expect(registry.registry).to include(mock_attribute)
      end

      it "returns self for method chaining" do
        result = registry.register(mock_attribute)

        expect(result).to be(registry)
      end
    end

    context "when registering multiple attributes as an array" do
      let(:second_attribute) { instance_double(CMDx::Attribute) }
      let(:attributes) { [mock_attribute, second_attribute] }

      it "adds all attributes to the registry" do
        registry.register(attributes)

        expect(registry.registry).to include(mock_attribute, second_attribute)
      end

      it "maintains the order of attributes" do
        registry.register(attributes)

        expect(registry.registry).to eq(attributes)
      end
    end

    context "when registering attributes to an existing registry" do
      let(:initial_registry) { [mock_attribute] }
      let(:new_attribute) { instance_double(CMDx::Attribute) }

      it "appends new attributes to existing ones" do
        registry.register(new_attribute)

        expect(registry.registry).to eq([mock_attribute, new_attribute])
      end
    end

    context "when registering nil" do
      it "adds nil to the registry as an empty array" do
        registry.register(nil)

        expect(registry.registry).to eq([])
      end
    end

    context "when registering a non-array value" do
      let(:single_value) { "string_value" }

      it "converts the value to an array before adding" do
        registry.register(single_value)

        expect(registry.registry).to eq([single_value])
      end
    end
  end

  describe "#define_and_verify" do
    let(:second_attribute) { instance_double(CMDx::Attribute) }
    let(:initial_registry) { [mock_attribute, second_attribute] }

    before do
      allow(mock_attribute).to receive(:task=)
      allow(mock_attribute).to receive(:define_and_verify_tree)
      allow(second_attribute).to receive(:task=)
      allow(second_attribute).to receive(:define_and_verify_tree)
    end

    it "sets the task on each attribute in the registry" do
      registry.define_and_verify(mock_task)

      expect(mock_attribute).to have_received(:task=).with(mock_task)
      expect(second_attribute).to have_received(:task=).with(mock_task)
    end

    it "calls define_and_verify_tree on each attribute" do
      registry.define_and_verify(mock_task)

      expect(mock_attribute).to have_received(:define_and_verify_tree)
      expect(second_attribute).to have_received(:define_and_verify_tree)
    end

    context "when registry is empty" do
      let(:initial_registry) { [] }

      it "does not raise an error" do
        expect { registry.define_and_verify(mock_task) }.not_to raise_error
      end
    end

    context "when an attribute raises an error" do
      before do
        allow(mock_attribute).to receive(:define_and_verify_tree).and_raise(StandardError, "test error")
      end

      it "propagates the error" do
        expect { registry.define_and_verify(mock_task) }.to raise_error(StandardError, "test error")
      end
    end
  end
end

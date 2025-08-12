# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Attribute do
  let(:task_class) { create_task_class }
  let(:task) { task_class.new }
  let(:attribute_name) { :test_attr }
  let(:options) { {} }

  describe "#initialize" do
    subject(:attribute) { described_class.new(attribute_name, options) }

    it "sets name and options" do
      aggregate_failures do
        expect(attribute.name).to eq(attribute_name)
        expect(attribute.options).to eq(options)
        expect(attribute.children).to eq([])
        expect(attribute.parent).to be_nil
        expect(attribute.types).to eq([])
      end
    end

    context "with parent option" do
      let(:parent_attribute) { described_class.new(:parent_attr) }
      let(:options) { { parent: parent_attribute } }

      it "sets parent and removes it from options" do
        aggregate_failures do
          expect(attribute.parent).to eq(parent_attribute)
          expect(attribute.options).not_to have_key(:parent)
        end
      end
    end

    context "with required option" do
      let(:options) { { required: true } }

      it "sets required and removes it from options" do
        aggregate_failures do
          expect(attribute.required?).to be(true)
          expect(attribute.options).not_to have_key(:required)
        end
      end
    end

    context "with types option" do
      let(:options) { { types: %i[string integer] } }

      it "sets types array and removes it from options" do
        aggregate_failures do
          expect(attribute.types).to eq(%i[string integer])
          expect(attribute.options).not_to have_key(:types)
        end
      end
    end

    context "with type option (singular)" do
      let(:options) { { type: :string } }

      it "converts single type to array and removes it from options" do
        aggregate_failures do
          expect(attribute.types).to eq([:string])
          expect(attribute.options).not_to have_key(:type)
        end
      end
    end

    context "with block" do
      it "executes block in instance context" do
        executed_block = []
        described_class.new(attribute_name, options) do
          executed_block << :executed
        end
        expect(executed_block).to contain_exactly(:executed)
      end
    end
  end

  describe ".define" do
    it "creates new attribute instance" do
      result = described_class.define(:test, required: true)
      aggregate_failures do
        expect(result).to be_a(described_class)
        expect(result.name).to eq(:test)
        expect(result.required?).to be(true)
      end
    end
  end

  describe ".defines" do
    context "with single attribute name" do
      it "returns array with one attribute" do
        result = described_class.defines(:test, required: true)
        aggregate_failures do
          expect(result).to be_an(Array)
          expect(result.size).to eq(1)
          expect(result.first.name).to eq(:test)
          expect(result.first.required?).to be(true)
        end
      end
    end

    context "with multiple attribute names" do
      it "returns array with multiple attributes" do
        result = described_class.defines(:test1, :test2, required: true)
        aggregate_failures do
          expect(result).to be_an(Array)
          expect(result.size).to eq(2)
          expect(result.map(&:name)).to eq(%i[test1 test2])
          expect(result.all?(&:required?)).to be(true)
        end
      end
    end

    context "with no names" do
      it "raises ArgumentError" do
        expect { described_class.defines }.to raise_error(ArgumentError, "no attributes given")
      end
    end

    context "with multiple names and :as option" do
      it "raises ArgumentError" do
        expect { described_class.defines(:test1, :test2, as: :alias) }
          .to raise_error(ArgumentError, ":as option only supports one attribute per definition")
      end
    end

    context "with single name and :as option" do
      it "creates attribute with :as option" do
        result = described_class.defines(:test, as: :alias)
        expect(result.first.options[:as]).to eq(:alias)
      end
    end
  end

  describe ".optional" do
    it "creates optional attributes" do
      result = described_class.optional(:test1, :test2)
      aggregate_failures do
        expect(result.size).to eq(2)
        expect(result.all? { |attr| !attr.required? }).to be(true)
      end
    end
  end

  describe ".required" do
    it "creates required attributes" do
      result = described_class.required(:test1, :test2)
      aggregate_failures do
        expect(result.size).to eq(2)
        expect(result.all?(&:required?)).to be(true)
      end
    end
  end

  describe "#required?" do
    context "when required is true" do
      subject(:attribute) { described_class.new(attribute_name, required: true) }

      it "returns true" do
        expect(attribute.required?).to be(true)
      end
    end

    context "when required is false" do
      subject(:attribute) { described_class.new(attribute_name, required: false) }

      it "returns false" do
        expect(attribute.required?).to be(false)
      end
    end

    context "when required is not set" do
      subject(:attribute) { described_class.new(attribute_name) }

      it "returns false" do
        expect(attribute.required?).to be(false)
      end
    end
  end

  describe "#source" do
    subject(:attribute) { described_class.new(attribute_name, options) }

    before { attribute.task = task }

    context "with parent having a method_name" do
      let(:parent_attribute) do
        described_class.new(:parent_attr, as: :parent_method).tap { |attr| attr.task = task }
      end
      let(:options) { { parent: parent_attribute } }

      it "returns parent's method_name" do
        expect(attribute.source).to eq(:parent_method)
      end
    end

    context "with source option as symbol" do
      let(:options) { { source: :custom_source } }

      it "returns the symbol" do
        expect(attribute.source).to eq(:custom_source)
      end
    end

    context "with source option as proc" do
      let(:options) { { source: proc { :proc_result } } }

      it "evaluates proc in task context" do
        expect(attribute.source).to eq(:proc_result)
      end
    end

    context "with source option as callable object" do
      let(:callable) { instance_double("callable", call: :callable_result) }
      let(:options) { { source: callable } }

      it "calls object with task" do
        expect(attribute.source).to eq(:callable_result)
        expect(callable).to have_received(:call).with(task)
      end
    end

    context "with source option as string" do
      let(:options) { { source: "string_source" } }

      it "returns the string" do
        expect(attribute.source).to eq("string_source")
      end
    end

    context "without source option and no parent" do
      it "returns :context as default" do
        expect(attribute.source).to eq(:context)
      end
    end
  end

  describe "#method_name" do
    subject(:attribute) { described_class.new(attribute_name, options) }

    before { attribute.task = task }

    context "with :as option" do
      let(:options) { { as: :custom_method } }

      it "returns the custom method name" do
        expect(attribute.method_name).to eq(:custom_method)
      end
    end

    context "with prefix option as true" do
      let(:options) { { source: :config, prefix: true } }

      it "includes source as prefix" do
        expect(attribute.method_name).to eq(:config_test_attr)
      end
    end

    context "with prefix option as string" do
      let(:options) { { prefix: "custom_" } }

      it "uses custom prefix" do
        expect(attribute.method_name).to eq(:custom_test_attr)
      end
    end

    context "with suffix option as true" do
      let(:options) { { source: :config, suffix: true } }

      it "includes source as suffix" do
        expect(attribute.method_name).to eq(:test_attr_config)
      end
    end

    context "with suffix option as string" do
      let(:options) { { suffix: "_custom" } }

      it "uses custom suffix" do
        expect(attribute.method_name).to eq(:test_attr_custom)
      end
    end

    context "with both prefix and suffix" do
      let(:options) { { source: :config, prefix: true, suffix: true } }

      it "includes both prefix and suffix" do
        expect(attribute.method_name).to eq(:config_test_attr_config)
      end
    end

    context "without prefix, suffix, or as options" do
      it "returns attribute name" do
        expect(attribute.method_name).to eq(:test_attr)
      end
    end
  end

  describe "#define_and_verify_tree" do
    subject(:attribute) { described_class.new(attribute_name, options) }

    let(:child1) { described_class.new(:child1) }
    let(:child2) { described_class.new(:child2) }
    let(:attribute_value_double) { instance_double(CMDx::AttributeValue) }

    before do
      attribute.task = task
      attribute.children.push(child1, child2)

      allow(CMDx::AttributeValue).to receive(:new).and_return(attribute_value_double)
      allow(attribute_value_double).to receive(:generate)
      allow(attribute_value_double).to receive(:validate)
      allow(task).to receive(:respond_to?).and_return(false)
      allow(task).to receive(:instance_eval)
    end

    it "calls define_and_verify on self and children" do
      attribute.define_and_verify_tree

      aggregate_failures do
        expect(child1.task).to eq(task)
        expect(child2.task).to eq(task)
        expect(CMDx::AttributeValue).to have_received(:new).exactly(3).times
        expect(attribute_value_double).to have_received(:generate).exactly(3).times
        expect(attribute_value_double).to have_received(:validate).exactly(3).times
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Attribute, type: :unit do
  let(:task_class) { create_task_class }
  let(:task) { task_class.new }
  let(:attribute_name) { :test_attr }
  let(:attribute_options) { {} }
  let(:attribute) { described_class.new(attribute_name, **attribute_options) }

  describe "#initialize" do
    # Arrange & Act
    subject(:new_attribute) { described_class.new(attribute_name, **attribute_options) }

    context "with basic parameters" do
      it "sets the name" do
        expect(new_attribute.name).to eq(attribute_name)
      end

      it "sets empty options" do
        expect(new_attribute.options).to eq({})
      end

      it "initializes empty children array" do
        expect(new_attribute.children).to eq([])
      end

      it "sets parent to nil" do
        expect(new_attribute.parent).to be_nil
      end

      it "sets required to false by default" do
        expect(new_attribute.required?).to be false
      end

      it "sets empty types array" do
        expect(new_attribute.types).to eq([])
      end
    end

    context "with parent option" do
      let(:parent_attribute) { described_class.new(:parent_attr) }
      let(:attribute_options) { { parent: parent_attribute } }

      it "sets the parent" do
        expect(new_attribute.parent).to eq(parent_attribute)
      end

      it "removes parent from options" do
        expect(new_attribute.options).not_to have_key(:parent)
      end
    end

    context "with required option" do
      let(:attribute_options) { { required: true } }

      it "sets required to true" do
        expect(new_attribute.required?).to be true
      end

      it "removes required from options" do
        expect(new_attribute.options).not_to have_key(:required)
      end
    end

    context "with types option" do
      let(:attribute_options) { { types: %i[string integer] } }

      it "sets types array" do
        expect(new_attribute.types).to eq(%i[string integer])
      end

      it "removes types from options" do
        expect(new_attribute.options).not_to have_key(:types)
      end
    end

    context "with type option (singular)" do
      let(:attribute_options) { { type: :string } }

      it "converts type to types array" do
        expect(new_attribute.types).to eq([:string])
      end

      it "removes type from options" do
        expect(new_attribute.options).not_to have_key(:type)
      end
    end

    context "with other options" do
      let(:attribute_options) { { source: :context, default: "value", as: :custom_name } }

      it "preserves other options" do
        expect(new_attribute.options).to eq({ source: :context, default: "value", as: :custom_name })
      end
    end

    context "with block" do
      it "executes the block in instance context" do
        expect do
          described_class.new(attribute_name) { nil }
        end.not_to raise_error
      end
    end
  end

  describe ".define" do
    subject(:defined_attribute) { described_class.define(attribute_name, **attribute_options) }

    it "creates a new attribute instance" do
      expect(defined_attribute).to be_a(described_class)
      expect(defined_attribute.name).to eq(attribute_name)
    end

    context "with options" do
      let(:attribute_options) { { required: true, type: :string } }

      it "passes options to initialize" do
        expect(defined_attribute.required?).to be true
        expect(defined_attribute.types).to eq([:string])
      end
    end
  end

  describe ".defines" do
    subject(:defined_attributes) { described_class.defines(*names, **attribute_options) }

    let(:names) { %i[attr1 attr2] }

    context "with multiple names" do
      it "creates attributes for each name" do
        expect(defined_attributes.size).to eq(2)
        expect(defined_attributes.map(&:name)).to eq(%i[attr1 attr2])
      end

      it "returns array of attributes" do
        expect(defined_attributes).to all(be_a(described_class))
      end
    end

    context "with no names" do
      let(:names) { [] }

      it "raises ArgumentError" do
        expect { defined_attributes }.to raise_error(ArgumentError, "no attributes given")
      end
    end

    context "with multiple names and :as option" do
      let(:attribute_options) { { as: :custom_name } }

      it "raises ArgumentError" do
        expect { defined_attributes }.to raise_error(ArgumentError, ":as option only supports one attribute per definition")
      end
    end

    context "with single name and :as option" do
      let(:names) { [:attr1] }
      let(:attribute_options) { { as: :custom_name } }

      it "creates attribute with custom name" do
        expect(defined_attributes.size).to eq(1)
        expect(defined_attributes.first.options[:as]).to eq(:custom_name)
      end
    end

    context "with block" do
      it "passes block to each attribute" do
        attributes = described_class.defines(*names) { nil }
        expect(attributes.size).to eq(2)
      end
    end
  end

  describe ".optional" do
    subject(:optional_attributes) { described_class.optional(*names, **attribute_options) }

    let(:names) { %i[attr1 attr2] }

    it "creates attributes with required: false" do
      expect(optional_attributes).to all(satisfy { |attr| !attr.required? })
    end

    context "with existing required option" do
      let(:attribute_options) { { required: true } }

      it "overrides with required: false" do
        expect(optional_attributes).to all(satisfy { |attr| !attr.required? })
      end
    end
  end

  describe ".required" do
    subject(:required_attributes) { described_class.required(*names, **attribute_options) }

    let(:names) { %i[attr1 attr2] }

    it "creates attributes with required: true" do
      expect(required_attributes).to all(satisfy(&:required?))
    end

    context "with existing required option" do
      let(:attribute_options) { { required: false } }

      it "overrides with required: true" do
        expect(required_attributes).to all(satisfy(&:required?))
      end
    end
  end

  describe "#required?" do
    subject { attribute.required? }

    context "when required is false" do
      let(:attribute_options) { { required: false } }

      it { is_expected.to be false }
    end

    context "when required is true" do
      let(:attribute_options) { { required: true } }

      it { is_expected.to be true }
    end

    context "when required is nil" do
      it { is_expected.to be false }
    end
  end

  describe "#source" do
    subject(:source_value) { attribute.source }

    before { attribute.task = task }

    context "when parent has method_name" do
      let(:parent_attribute) do
        described_class.new(:parent_attr).tap do |attr|
          allow(attr).to receive(:method_name).and_return(:parent_method)
        end
      end
      let(:attribute_options) { { parent: parent_attribute } }

      it "returns parent method_name" do
        expect(source_value).to eq(:parent_method)
      end
    end

    context "without parent" do
      context "when source option is a symbol" do
        let(:attribute_options) { { source: :custom_source } }

        it "returns the symbol" do
          expect(source_value).to eq(:custom_source)
        end
      end

      context "when source option is a proc" do
        let(:attribute_options) { { source: proc { :proc_result } } }

        it "evaluates proc in task context" do
          expect(source_value).to eq(:proc_result)
        end
      end

      context "when source option responds to call" do
        let(:callable_source) do
          object = Object.new
          allow(object).to receive(:call).and_return(:callable_result)
          object
        end
        let(:attribute_options) { { source: callable_source } }

        it "calls the object with task" do
          expect(callable_source).to receive(:call).with(task)
          expect(source_value).to eq(:callable_result)
        end
      end

      context "when source option is a string" do
        let(:attribute_options) { { source: "string_source" } }

        it "returns the string" do
          expect(source_value).to eq("string_source")
        end
      end

      context "without source option" do
        it "returns :context as default" do
          expect(source_value).to eq(:context)
        end
      end
    end

    context "with memoization" do
      let(:attribute_options) { { source: proc { Time.now.to_f } } }

      it "memoizes the result" do
        first_result = attribute.source
        second_result = attribute.source
        expect(first_result).to eq(second_result)
      end
    end
  end

  describe "#method_name" do
    subject(:method_name_value) { attribute.method_name }

    before { attribute.task = task }

    context "when :as option is provided" do
      let(:attribute_options) { { as: :custom_method } }

      it "returns the custom method name" do
        expect(method_name_value).to eq(:custom_method)
      end
    end

    context "without :as option" do
      context "with default settings" do
        it "returns the attribute name" do
          expect(method_name_value).to eq(attribute_name)
        end
      end

      context "with prefix option set to true" do
        let(:attribute_options) { { prefix: true, source: :params } }

        it "adds source as prefix" do
          expect(method_name_value).to eq(:params_test_attr)
        end
      end

      context "with prefix option set to string" do
        let(:attribute_options) { { prefix: "custom" } }

        it "uses custom prefix" do
          expect(method_name_value).to eq(:customtest_attr)
        end
      end

      context "with suffix option set to true" do
        let(:attribute_options) { { suffix: true, source: :params } }

        it "adds source as suffix" do
          expect(method_name_value).to eq(:test_attr_params)
        end
      end

      context "with suffix option set to string" do
        let(:attribute_options) { { suffix: "custom" } }

        it "uses custom suffix" do
          expect(method_name_value).to eq(:test_attrcustom)
        end
      end

      context "with both prefix and suffix" do
        let(:attribute_options) { { prefix: "pre", suffix: "suf" } }

        it "combines both" do
          expect(method_name_value).to eq(:pretest_attrsuf)
        end
      end
    end

    context "with memoization" do
      it "memoizes the result" do
        first_result = attribute.method_name
        second_result = attribute.method_name
        expect(first_result).to equal(second_result)
      end
    end
  end

  describe "#define_and_verify_tree" do
    let(:child1) { described_class.new(:child1) }
    let(:child2) { described_class.new(:child2) }

    before do
      attribute.task = task
      attribute.children.push(child1, child2)
      allow(attribute).to receive(:define_and_verify)
      allow(child1).to receive(:define_and_verify_tree)
      allow(child2).to receive(:define_and_verify_tree)
    end

    it "calls define_and_verify on self" do
      expect(attribute).to receive(:define_and_verify)
      attribute.define_and_verify_tree
    end

    it "sets task on all children" do
      attribute.define_and_verify_tree
      expect(child1.task).to eq(task)
      expect(child2.task).to eq(task)
    end

    it "calls define_and_verify_tree on all children" do
      expect(child1).to receive(:define_and_verify_tree)
      expect(child2).to receive(:define_and_verify_tree)
      attribute.define_and_verify_tree
    end
  end

  describe "private methods" do
    describe "#attribute" do
      let(:child_options) { { required: true } }

      before do
        attribute.send(:attribute, :child_attr, **child_options)
      end

      it "creates child attribute" do
        expect(attribute.children.size).to eq(1)
        expect(attribute.children.first.name).to eq(:child_attr)
      end

      it "sets parent on child" do
        expect(attribute.children.first.parent).to eq(attribute)
      end

      it "merges parent option with provided options" do
        expect(attribute.children.first.required?).to be true
      end
    end

    describe "#attributes" do
      let(:names) { %i[child1 child2] }
      let(:child_options) { { required: true } }

      before do
        attribute.send(:attributes, *names, **child_options)
      end

      it "creates multiple child attributes" do
        expect(attribute.children.size).to eq(2)
        expect(attribute.children.map(&:name)).to eq(%i[child1 child2])
      end

      it "sets parent on all children" do
        expect(attribute.children).to all(have_attributes(parent: attribute))
      end
    end

    describe "#optional" do
      before do
        attribute.send(:optional, :child1, :child2, type: :string)
      end

      it "creates optional child attributes" do
        expect(attribute.children.size).to eq(2)
        expect(attribute.children).to all(satisfy { |attr| !attr.required? })
      end
    end

    describe "#required" do
      before do
        attribute.send(:required, :child1, :child2, type: :string)
      end

      it "creates required child attributes" do
        expect(attribute.children.size).to eq(2)
        expect(attribute.children).to all(satisfy(&:required?))
      end
    end

    describe "#define_and_verify" do
      let(:attribute_value) { instance_double(CMDx::AttributeValue, generate: nil, validate: nil) }

      before do
        attribute.task = task
        allow(CMDx::AttributeValue).to receive(:new).and_return(attribute_value)
        allow(attribute).to receive(:method_name).and_return(:test_method)
      end

      context "when method is not already defined" do
        before do
          allow(task).to receive(:respond_to?).with(:test_method, true).and_return(false)
        end

        it "creates AttributeValue instance" do
          expect(CMDx::AttributeValue).to receive(:new).with(attribute)
          attribute.send(:define_and_verify)
        end

        it "calls generate and validate on AttributeValue" do
          expect(attribute_value).to receive(:generate)
          expect(attribute_value).to receive(:validate)
          attribute.send(:define_and_verify)
        end

        it "defines method on task" do
          expect(task).to receive(:instance_eval) do |code|
            expect(code).to include("def test_method")
            expect(code).to include("attributes[:test_method]")
          end
          attribute.send(:define_and_verify)
        end
      end

      context "when method is already defined" do
        before do
          allow(task).to receive(:respond_to?).with(:test_method, true).and_return(true)
          allow(task.class).to receive(:name).and_return("TestTask")
        end

        it "raises error" do
          expect do
            attribute.send(:define_and_verify)
          end.to raise_error("TestTask#test_method already defined")
        end
      end
    end
  end

  describe "AFFIX constant" do
    subject(:affix_proc) { described_class.const_get(:AFFIX) }

    it "is a frozen proc" do
      expect(affix_proc).to be_a(Proc)
      expect(affix_proc).to be_frozen
    end

    context "when value is true" do
      it "calls the block" do
        result = affix_proc.call(true) { "block_result" }
        expect(result).to eq("block_result")
      end
    end

    context "when value is not true" do
      it "returns the value" do
        result = affix_proc.call("custom_value") { "block_result" }
        expect(result).to eq("custom_value")
      end
    end
  end
end

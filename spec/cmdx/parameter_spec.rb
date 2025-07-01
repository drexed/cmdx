# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Parameter do
  let(:task_class) { Class.new(CMDx::Task) }

  describe "initialization" do
    context "when creating a basic parameter" do
      it "creates a parameter with required options" do
        parameter = described_class.new(:user_id, klass: task_class)

        expect(parameter.name).to eq(:user_id)
        expect(parameter.klass).to eq(task_class)
        expect(parameter.type).to eq(:virtual)
        expect(parameter.required?).to be(false)
      end

      it "creates a parameter with custom type" do
        parameter = described_class.new(:age, klass: task_class, type: :integer)

        expect(parameter.name).to eq(:age)
        expect(parameter.type).to eq(:integer)
      end

      it "creates a required parameter" do
        parameter = described_class.new(:email, klass: task_class, required: true)

        expect(parameter.name).to eq(:email)
        expect(parameter.required?).to be(true)
        expect(parameter.optional?).to be(false)
      end

      it "stores additional options" do
        options = { format: { with: /@/ }, presence: true }
        parameter = described_class.new(:email, klass: task_class, **options)

        expect(parameter.options).to include(format: { with: /@/ }, presence: true)
      end

      it "initializes empty children array" do
        parameter = described_class.new(:user, klass: task_class)

        expect(parameter.children).to eq([])
      end

      it "initializes errors object" do
        parameter = described_class.new(:user, klass: task_class)

        expect(parameter.errors).to be_a(CMDx::Errors)
      end
    end

    context "when creating nested parameters" do
      it "sets parent parameter correctly" do
        parent = described_class.new(:user, klass: task_class)
        child = described_class.new(:name, klass: task_class, parent: parent)

        expect(child.parent).to eq(parent)
      end

      it "processes block for nested parameter definitions" do
        parameter = described_class.new(:address, klass: task_class) do
          required :street, :city
          optional :apartment
        end

        expect(parameter.children.size).to eq(3)
        expect(parameter.children.map(&:name)).to contain_exactly(:street, :city, :apartment)
      end
    end

    context "when handling errors" do
      it "raises KeyError when klass option is missing" do
        expect do
          described_class.new(:user_id)
        end.to raise_error(KeyError, "klass option required")
      end
    end

    context "when defining methods on task class" do
      it "defines the parameter method on the task class" do
        described_class.new(:user_id, klass: task_class)

        expect(task_class.private_method_defined?(:user_id)).to be(true)
      end

      it "defines method with custom name when using as option" do
        described_class.new(:id, klass: task_class, as: :user_id)

        expect(task_class.private_method_defined?(:user_id)).to be(true)
      end
    end
  end

  describe ".optional" do
    context "when defining single optional parameter" do
      it "creates one optional parameter" do
        parameters = described_class.optional(:priority, klass: task_class, type: :string)

        expect(parameters.size).to eq(1)
        expect(parameters.first.name).to eq(:priority)
        expect(parameters.first.required?).to be(false)
        expect(parameters.first.type).to eq(:string)
      end

      it "creates parameter with validation options" do
        parameters = described_class.optional(:email, klass: task_class, format: { with: /@/ })

        parameter = parameters.first
        expect(parameter.options).to include(format: { with: /@/ })
      end

      it "processes block for nested parameters" do
        parameters = described_class.optional(:address, klass: task_class) do
          required :street
        end

        parameter = parameters.first
        expect(parameter.children.size).to eq(1)
        expect(parameter.children.first.name).to eq(:street)
        expect(parameter.children.first.required?).to be(true)
      end
    end

    context "when defining multiple optional parameters" do
      it "creates multiple parameters with same options" do
        parameters = described_class.optional(:width, :height, klass: task_class, type: :integer)

        expect(parameters.size).to eq(2)
        expect(parameters.map(&:name)).to contain_exactly(:width, :height)
        expect(parameters.all? { |p| p.type == :integer }).to be(true)
        expect(parameters.all?(&:optional?)).to be(true)
      end

      it "applies validation options to all parameters" do
        options = { numeric: { min: 0 } }
        parameters = described_class.optional(:x, :y, klass: task_class, **options)

        expect(parameters.all? { |p| p.options[:numeric] == { min: 0 } }).to be(true)
      end
    end

    context "when handling errors" do
      it "raises ArgumentError when no parameters given" do
        expect do
          described_class.optional(klass: task_class)
        end.to raise_error(ArgumentError, "no parameters given")
      end

      it "raises ArgumentError when :as option used with multiple parameters" do
        expect do
          described_class.optional(:width, :height, klass: task_class, as: :dimensions)
        end.to raise_error(ArgumentError, ":as option only supports one parameter per definition")
      end
    end
  end

  describe ".required" do
    context "when defining single required parameter" do
      it "creates one required parameter" do
        parameters = described_class.required(:user_id, klass: task_class, type: :integer)

        expect(parameters.size).to eq(1)
        expect(parameters.first.name).to eq(:user_id)
        expect(parameters.first.required?).to be(true)
        expect(parameters.first.type).to eq(:integer)
      end

      it "merges required: true with other options" do
        parameters = described_class.required(:age, klass: task_class, numeric: { min: 18 })

        parameter = parameters.first
        expect(parameter.required?).to be(true)
        expect(parameter.options).to include(numeric: { min: 18 })
      end
    end

    context "when defining multiple required parameters" do
      it "creates multiple required parameters" do
        parameters = described_class.required(:first_name, :last_name, klass: task_class, type: :string)

        expect(parameters.size).to eq(2)
        expect(parameters.map(&:name)).to contain_exactly(:first_name, :last_name)
        expect(parameters.all?(&:required?)).to be(true)
      end
    end

    context "when handling errors" do
      it "raises ArgumentError when no parameters given" do
        expect do
          described_class.required(klass: task_class)
        end.to raise_error(ArgumentError, "no parameters given")
      end

      it "raises ArgumentError when :as option used with multiple parameters" do
        expect do
          described_class.required(:first, :last, klass: task_class, as: :name)
        end.to raise_error(ArgumentError, ":as option only supports one parameter per definition")
      end
    end
  end

  describe "#optional" do
    let(:parent_parameter) { described_class.new(:user, klass: task_class) }

    context "when defining nested optional parameters" do
      it "creates child parameters with parent reference" do
        parent_parameter.optional(:name, :email, type: :string)

        expect(parent_parameter.children.size).to eq(2)
        expect(parent_parameter.children.map(&:name)).to contain_exactly(:name, :email)
        expect(parent_parameter.children.all? { |c| c.parent == parent_parameter }).to be(true)
        expect(parent_parameter.children.all?(&:optional?)).to be(true)
      end

      it "passes options to child parameters" do
        parent_parameter.optional(:age, type: :integer, numeric: { min: 0 })

        child = parent_parameter.children.first
        expect(child.type).to eq(:integer)
        expect(child.options).to include(numeric: { min: 0 })
      end

      it "processes blocks for further nesting" do
        parent_parameter.optional(:address) do
          required :street
        end

        address_param = parent_parameter.children.first
        expect(address_param.children.size).to eq(1)
        expect(address_param.children.first.name).to eq(:street)
      end
    end
  end

  describe "#required" do
    let(:parent_parameter) { described_class.new(:order, klass: task_class) }

    context "when defining nested required parameters" do
      it "creates required child parameters" do
        parent_parameter.required(:total, :currency, type: :string)

        expect(parent_parameter.children.size).to eq(2)
        expect(parent_parameter.children.all?(&:required?)).to be(true)
        expect(parent_parameter.children.all? { |c| c.parent == parent_parameter }).to be(true)
      end

      it "sets klass and parent correctly" do
        parent_parameter.required(:amount, type: :float)

        child = parent_parameter.children.first
        expect(child.klass).to eq(task_class)
        expect(child.parent).to eq(parent_parameter)
      end
    end
  end

  describe "#required?" do
    context "when parameter is required" do
      it "returns true" do
        parameter = described_class.new(:user_id, klass: task_class, required: true)

        expect(parameter.required?).to be(true)
      end
    end

    context "when parameter is optional" do
      it "returns false" do
        parameter = described_class.new(:priority, klass: task_class, required: false)

        expect(parameter.required?).to be(false)
      end
    end
  end

  describe "#optional?" do
    context "when parameter is optional" do
      it "returns true" do
        parameter = described_class.new(:priority, klass: task_class, required: false)

        expect(parameter.optional?).to be(true)
      end
    end

    context "when parameter is required" do
      it "returns false" do
        parameter = described_class.new(:user_id, klass: task_class, required: true)

        expect(parameter.optional?).to be(false)
      end
    end
  end

  describe "#method_name" do
    context "when using default naming" do
      it "returns the parameter name" do
        parameter = described_class.new(:user_id, klass: task_class)

        expect(parameter.method_name).to eq(:user_id)
      end
    end

    context "when using custom naming options" do
      it "uses the :as option for method name" do
        parameter = described_class.new(:id, klass: task_class, as: :user_id)

        expect(parameter.method_name).to eq(:user_id)
      end

      it "applies prefix when specified" do
        parameter = described_class.new(:name, klass: task_class, prefix: "get_")

        expect(parameter.method_name).to eq(:get_name)
      end

      it "applies suffix when specified" do
        parameter = described_class.new(:name, klass: task_class, suffix: "_value")

        expect(parameter.method_name).to eq(:name_value)
      end
    end

    context "when method name is cached" do
      it "returns the same value on subsequent calls" do
        parameter = described_class.new(:user_id, klass: task_class)

        first_call = parameter.method_name
        second_call = parameter.method_name

        expect(first_call).to eq(second_call)
        expect(first_call).to eq(:user_id)
      end
    end
  end

  describe "#method_source" do
    context "when using default source" do
      it "returns :context" do
        parameter = described_class.new(:user_id, klass: task_class)

        expect(parameter.method_source).to eq(:context)
      end
    end

    context "when using custom source" do
      it "returns the specified source" do
        parameter = described_class.new(:name, klass: task_class, source: :user)

        expect(parameter.method_source).to eq(:user)
      end
    end

    context "when parameter has parent" do
      it "returns parent's method name as source" do
        parent = described_class.new(:user, klass: task_class)
        child = described_class.new(:name, klass: task_class, parent: parent)

        allow(parent).to receive(:method_name).and_return(:user)

        expect(child.method_source).to eq(:user)
      end
    end

    context "when method source is cached" do
      it "returns cached value on subsequent calls" do
        parameter = described_class.new(:user_id, klass: task_class)

        parameter.method_source
        parameter.method_source

        expect(parameter.instance_variable_get(:@method_source)).to eq(:context)
      end
    end
  end

  describe "#to_h" do
    context "when serializing parameter" do
      it "delegates to ParameterSerializer" do
        parameter = described_class.new(:user_id, klass: task_class, type: :integer)
        serialized_hash = { name: :user_id, type: :integer, required: false }

        expect(CMDx::ParameterSerializer).to receive(:call).with(parameter).and_return(serialized_hash)

        result = parameter.to_h

        expect(result).to eq(serialized_hash)
      end
    end
  end

  describe "#to_s" do
    context "when converting to string" do
      it "delegates to ParameterInspector with serialized hash" do
        parameter = described_class.new(:email, klass: task_class, type: :string)
        serialized_hash = { name: :email, type: :string, required: false }
        inspection_string = "Parameter: name=email type=string required=false"

        allow(parameter).to receive(:to_h).and_return(serialized_hash)
        expect(CMDx::ParameterInspector).to receive(:call).with(serialized_hash).and_return(inspection_string)

        result = parameter.to_s

        expect(result).to eq(inspection_string)
      end
    end
  end

  describe "method definition behavior" do
    let(:task_instance) { task_class.new }

    context "when parameter methods are called" do
      it "creates parameter value and handles caching" do
        parameter = described_class.new(:user_id, klass: task_class, type: :integer)
        parameter_value = double("ParameterValue")

        expect(CMDx::ParameterValue).to receive(:new).with(task_instance, parameter).and_return(parameter_value)
        expect(parameter_value).to receive(:call).and_return(123)

        result = task_instance.send(:user_id)

        expect(result).to eq(123)
      end

      it "caches parameter values on subsequent calls" do
        described_class.new(:user_id, klass: task_class, type: :integer)
        parameter_value = double("ParameterValue")

        expect(CMDx::ParameterValue).to receive(:new).once.and_return(parameter_value)
        expect(parameter_value).to receive(:call).once.and_return(123)

        task_instance.send(:user_id)
        result = task_instance.send(:user_id)

        expect(result).to eq(123)
      end

      it "handles coercion errors by adding to parameter errors" do
        parameter = described_class.new(:age, klass: task_class, type: :integer)
        parameter_value = double("ParameterValue")
        error = CMDx::CoercionError.new("Invalid integer")

        allow(CMDx::ParameterValue).to receive(:new).and_return(parameter_value)
        allow(parameter_value).to receive(:call).and_raise(error)

        task_instance.send(:age)

        expect(parameter.errors[:age]).to include("Invalid integer")
      end

      it "handles validation errors by adding to parameter errors" do
        parameter = described_class.new(:email, klass: task_class, type: :string)
        parameter_value = double("ParameterValue")
        error = CMDx::ValidationError.new("Invalid format")

        allow(CMDx::ParameterValue).to receive(:new).and_return(parameter_value)
        allow(parameter_value).to receive(:call).and_raise(error)

        task_instance.send(:email)

        expect(parameter.errors[:email]).to include("Invalid format")
      end
    end
  end

  describe "parameter hierarchy and relationships" do
    context "when working with nested parameter structures" do
      it "maintains parent-child relationships correctly" do
        parent = described_class.new(:shipping, klass: task_class)
        parent.required(:address) do
          required :street, :city
          optional :apartment
        end

        address_param = parent.children.first
        street_param = address_param.children.find { |c| c.name == :street }

        expect(address_param.parent).to eq(parent)
        expect(street_param.parent).to eq(address_param)
        expect(parent.children).to contain_exactly(address_param)
        expect(address_param.children.size).to eq(3)
      end

      it "inherits task class through nested levels" do
        parent = described_class.new(:user, klass: task_class)
        parent.optional(:profile) do
          required :bio, :avatar_url
        end

        profile_param = parent.children.first
        bio_param = profile_param.children.first

        expect(profile_param.klass).to eq(task_class)
        expect(bio_param.klass).to eq(task_class)
      end
    end
  end

  describe "error delegation" do
    context "when using delegated methods" do
      it "delegates invalid? to errors" do
        parameter = described_class.new(:email, klass: task_class)

        allow(parameter.errors).to receive(:invalid?).and_return(true)

        expect(parameter.invalid?).to be(true)
      end

      it "delegates valid? to errors" do
        parameter = described_class.new(:email, klass: task_class)

        allow(parameter.errors).to receive(:valid?).and_return(false)

        expect(parameter.valid?).to be(false)
      end
    end
  end
end

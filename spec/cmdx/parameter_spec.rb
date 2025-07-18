# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Parameter do
  let(:task_class) { create_simple_task(name: "TestTask") }
  let(:param_options) { { klass: task_class } }

  describe ".optional" do
    context "with single parameter name" do
      it "creates optional parameter with default options" do
        parameters = described_class.optional(:name, **param_options)

        expect(parameters.length).to eq(1)
        expect(parameters.first).to be_a(described_class)
        expect(parameters.first.name).to eq(:name)
        expect(parameters.first.required?).to be(false)
        expect(parameters.first.type).to eq(:virtual)
      end

      it "creates optional parameter with custom type" do
        parameters = described_class.optional(:email, type: :string, **param_options)

        expect(parameters.first.type).to eq(:string)
        expect(parameters.first.optional?).to be(true)
      end

      it "creates parameter with additional options" do
        parameters = described_class.optional(:count, type: :integer, default: 10, **param_options)

        expect(parameters.first.options).to include(default: 10)
      end

      it "creates parameter with nested structure using block" do
        parameters = described_class.optional(:user, type: :hash, **param_options) do
          required :name, type: :string
          optional :age, type: :integer
        end

        parameter = parameters.first
        expect(parameter.children.length).to eq(2)
        expect(parameter.children.first.name).to eq(:name)
        expect(parameter.children.first.required?).to be(true)
        expect(parameter.children.last.name).to eq(:age)
        expect(parameter.children.last.optional?).to be(true)
      end
    end

    context "with multiple parameter names" do
      it "creates multiple optional parameters" do
        parameters = described_class.optional(:name, :email, :phone, type: :string, **param_options)

        expect(parameters.length).to eq(3)
        parameters.each do |param|
          expect(param).to be_a(described_class)
          expect(param.type).to eq(:string)
          expect(param.optional?).to be(true)
        end
      end

      it "creates parameters with correct names" do
        parameters = described_class.optional(:first_name, :last_name, **param_options)
        names = parameters.map(&:name)

        expect(names).to eq(%i[first_name last_name])
      end
    end

    context "with invalid arguments" do
      it "raises ArgumentError when no parameters given" do
        expect { described_class.optional(**param_options) }.to raise_error(
          ArgumentError, "no parameters given"
        )
      end

      it "raises ArgumentError when :as option used with multiple names" do
        expect do
          described_class.optional(:name, :email, as: :user_info, **param_options)
        end.to raise_error(
          ArgumentError, ":as option only supports one parameter per definition"
        )
      end
    end
  end

  describe ".required" do
    context "with single parameter name" do
      it "creates required parameter with default options" do
        parameters = described_class.required(:name, **param_options)

        expect(parameters.length).to eq(1)
        expect(parameters.first.name).to eq(:name)
        expect(parameters.first.required?).to be(true)
        expect(parameters.first.type).to eq(:virtual)
      end

      it "creates required parameter with custom type" do
        parameters = described_class.required(:age, type: :integer, **param_options)

        expect(parameters.first.type).to eq(:integer)
        expect(parameters.first.required?).to be(true)
      end

      it "creates parameter with validation options" do
        parameters = described_class.required(:email, type: :string,
                                                      format: { with: /@/ }, **param_options)

        expect(parameters.first.options).to include(format: { with: /@/ })
      end
    end

    context "with multiple parameter names" do
      it "creates multiple required parameters" do
        parameters = described_class.required(:name, :email, type: :string, **param_options)

        expect(parameters.length).to eq(2)
        parameters.each do |param|
          expect(param.required?).to be(true)
          expect(param.type).to eq(:string)
        end
      end
    end

    context "with nested structure" do
      it "creates required parameter with nested children" do
        parameters = described_class.required(:user, type: :hash, **param_options) do
          required :name, type: :string
          optional :preferences, type: :hash do
            optional :theme, type: :string
          end
        end

        parameter = parameters.first
        expect(parameter.required?).to be(true)
        expect(parameter.children.length).to eq(2)

        preferences_param = parameter.children.find { |c| c.name == :preferences }
        expect(preferences_param.children.length).to eq(1)
        expect(preferences_param.children.first.name).to eq(:theme)
      end
    end
  end

  describe "#initialize" do
    subject(:parameter) { described_class.new(:name, **param_options) }

    it "sets basic attributes correctly" do
      expect(parameter.name).to eq(:name)
      expect(parameter.klass).to eq(task_class)
      expect(parameter.type).to eq(:virtual)
      expect(parameter.required?).to be(false)
      expect(parameter.children).to be_empty
      expect(parameter.errors).to be_a(CMDx::Errors)
    end

    it "accepts custom type" do
      parameter = described_class.new(:email, type: :string, **param_options)

      expect(parameter.type).to eq(:string)
    end

    it "accepts required flag" do
      parameter = described_class.new(:name, required: true, **param_options)

      expect(parameter.required?).to be(true)
    end

    it "accepts parent parameter" do
      parent = described_class.new(:user, **param_options)
      child = described_class.new(:name, parent: parent, **param_options)

      expect(child.parent).to eq(parent)
    end

    it "stores additional options" do
      parameter = described_class.new(:count, default: 10, numeric: { min: 0 }, **param_options)

      expect(parameter.options).to include(default: 10, numeric: { min: 0 })
    end

    it "evaluates block for nested parameters" do
      parameter = described_class.new(:user, **param_options) do
        required :name, type: :string
        optional :age, type: :integer
      end

      expect(parameter.children.length).to eq(2)
      expect(parameter.children.first.name).to eq(:name)
      expect(parameter.children.last.name).to eq(:age)
    end

    context "without klass option" do
      it "raises KeyError" do
        expect { described_class.new(:name) }.to raise_error(KeyError, "klass option required")
      end
    end

    context "with method definition" do
      it "defines parameter accessor method on task class" do
        parameter = described_class.new(:test_param, **param_options)

        expect(task_class.private_method_defined?(parameter.method_name)).to be(true)
      end
    end
  end

  describe "#optional" do
    subject(:parameter) { described_class.new(:user, **param_options) }

    it "creates optional child parameters" do
      parameters = parameter.optional(:nickname, :bio, type: :string)

      expect(parameters.length).to eq(2)
      expect(parameter.children.length).to eq(2)
      parameters.each do |param|
        expect(param.optional?).to be(true)
        expect(param.parent).to eq(parameter)
        expect(param.klass).to eq(task_class)
      end
    end

    it "creates nested parameters with block" do
      parameters = parameter.optional(:preferences, type: :hash) do
        required :theme, type: :string
      end

      preferences_param = parameters.first
      expect(preferences_param.children.length).to eq(1)
      expect(preferences_param.children.first.name).to eq(:theme)
      expect(preferences_param.children.first.required?).to be(true)
    end
  end

  describe "#required" do
    subject(:parameter) { described_class.new(:user, **param_options) }

    it "creates required child parameters" do
      parameters = parameter.required(:first_name, :last_name, type: :string)

      expect(parameters.length).to eq(2)
      expect(parameter.children.length).to eq(2)
      parameters.each do |param|
        expect(param.required?).to be(true)
        expect(param.parent).to eq(parameter)
        expect(param.klass).to eq(task_class)
      end
    end

    it "creates nested parameters with validation" do
      parameters = parameter.required(:email, type: :string,
                                              format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i })

      email_param = parameters.first
      expect(email_param.required?).to be(true)
      expect(email_param.options).to include(format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i })
    end
  end

  describe "#required?" do
    it "returns true for required parameters" do
      parameter = described_class.new(:name, required: true, **param_options)

      expect(parameter.required?).to be(true)
    end

    it "returns false for optional parameters" do
      parameter = described_class.new(:name, **param_options)

      expect(parameter.required?).to be(false)
    end
  end

  describe "#optional?" do
    it "returns true for optional parameters" do
      parameter = described_class.new(:name, **param_options)

      expect(parameter.optional?).to be(true)
    end

    it "returns false for required parameters" do
      parameter = described_class.new(:name, required: true, **param_options)

      expect(parameter.optional?).to be(false)
    end
  end

  describe "#method_name" do
    it "returns parameter name by default" do
      parameter = described_class.new(:user_name, **param_options)

      expect(parameter.method_name).to eq(:user_name)
    end

    it "uses name affix utility for method name generation" do
      expect(CMDx::Utils::NameAffix).to receive(:call).with(:name, :context, {})
                                                      .and_return(:generated_name)

      parameter = described_class.new(:name, **param_options)

      expect(parameter.method_name).to eq(:generated_name)
    end

    it "caches method name" do
      parameter = described_class.new(:name, **param_options)
      first_call = parameter.method_name
      second_call = parameter.method_name

      expect(first_call).to eq(second_call)
      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end

  describe "#method_source" do
    it "returns :context by default" do
      parameter = described_class.new(:name, **param_options)

      expect(parameter.method_source).to eq(:context)
    end

    it "returns custom source when specified" do
      parameter = described_class.new(:name, source: :request, **param_options)

      expect(parameter.method_source).to eq(:request)
    end

    it "returns parent method_name when parent exists" do
      parent = described_class.new(:user, **param_options)
      allow(parent).to receive(:method_name).and_return(:user_data)
      child = described_class.new(:name, parent: parent, **param_options)

      expect(child.method_source).to eq(:user_data)
    end

    it "caches method source" do
      parameter = described_class.new(:name, **param_options)
      first_call = parameter.method_source
      second_call = parameter.method_source

      expect(first_call).to eq(second_call)
    end
  end

  describe "#to_h" do
    it "delegates to ParameterSerializer" do
      parameter = described_class.new(:name, **param_options)
      expected_hash = { name: :name, type: :virtual }

      expect(CMDx::ParameterSerializer).to receive(:call).with(parameter).and_return(expected_hash)

      expect(parameter.to_h).to eq(expected_hash)
    end
  end

  describe "#to_s" do
    it "delegates to ParameterInspector with serialized hash" do
      parameter = described_class.new(:name, **param_options)
      param_hash = { name: :name, type: :virtual }
      expected_string = "Parameter(name: name, type: virtual)"

      allow(parameter).to receive(:to_h).and_return(param_hash)
      expect(CMDx::ParameterInspector).to receive(:call).with(param_hash).and_return(expected_string)

      expect(parameter.to_s).to eq(expected_string)
    end
  end

  describe "error delegation" do
    subject(:parameter) { described_class.new(:name, **param_options) }

    describe "#valid?" do
      it "delegates to errors.valid?" do
        expect(parameter.errors).to receive(:valid?).and_return(true)

        expect(parameter.valid?).to be(true)
      end
    end

    describe "#invalid?" do
      it "delegates to errors.invalid?" do
        expect(parameter.errors).to receive(:invalid?).and_return(false)

        expect(parameter.invalid?).to be(false)
      end
    end
  end

  describe "integration with tasks" do
    context "with simple parameters" do
      let(:task_class) do
        create_simple_task(name: "ParameterTask") do
          required :name, type: :string
          optional :age, type: :integer, default: 25

          def call
            context.processed_name = name
            context.user_age = age
          end
        end
      end

      it "works with required parameters" do
        result = task_class.call(name: "John")

        expect(result).to be_success
        expect(result.context.processed_name).to eq("John")
        expect(result.context.user_age).to eq(25)
      end

      it "fails when required parameter is missing" do
        result = task_class.call({})

        expect(result).to be_failed
        expect(result.metadata[:reason]).to include("name is a required parameter")
      end

      it "coerces parameter types" do
        result = task_class.call(name: 123, age: "30")

        expect(result).to be_success
        expect(result.context.processed_name).to eq("123")
        expect(result.context.user_age).to eq(30)
      end
    end

    context "with nested parameters" do
      let(:task_class) do
        create_simple_task(name: "NestedParameterTask") do
          required :user, type: :hash do
            required :name, type: :string
            optional :contact, type: :hash do
              optional :email, type: :string
              optional :phone, type: :string
            end
          end

          def call
            context.user_name = user[:name]
            context.user_email = user.dig(:contact, :email)
          end
        end
      end

      it "works with nested hash parameters" do
        result = task_class.call(
          user: {
            name: "John Doe",
            contact: { email: "john@example.com" }
          }
        )

        expect(result).to be_success
        expect(result.context.user_name).to eq("John Doe")
        expect(result.context.user_email).to eq("john@example.com")
      end

      it "fails when nested required parameter is missing" do
        result = task_class.call(user: { contact: { email: "john@example.com" } })

        expect(result).to be_failed
        expect(result.metadata[:reason]).to include("is a required parameter")
      end
    end

    context "with parameter validation" do
      let(:task_class) do
        create_simple_task(name: "ValidatedParameterTask") do
          required :email, type: :string, format: { with: /@/ }
          optional :age, type: :integer, numeric: { min: 18, max: 120 }

          def call
            context.valid_email = email
            context.valid_age = age
          end
        end
      end

      it "validates parameters successfully" do
        result = task_class.call(email: "test@example.com", age: 25)

        expect(result).to be_success
        expect(result.context.valid_email).to eq("test@example.com")
        expect(result.context.valid_age).to eq(25)
      end

      it "fails when validation rules are violated" do
        result = task_class.call(email: "invalid-email", age: 15)

        expect(result).to be_failed
        expect(result.metadata[:reason]).to include("is an invalid format")
      end
    end

    context "with coercion errors" do
      let(:task_class) do
        create_simple_task(name: "CoercionErrorTask") do
          required :count, type: :integer

          def call
            context.processed_count = count
          end
        end
      end

      it "handles coercion errors gracefully" do
        result = task_class.call(count: "not-a-number")

        expect(result).to be_failed
        expect(result.metadata[:reason]).to include("could not coerce into an integer")
      end
    end

    context "with parameter caching" do
      let(:task_class) do
        create_simple_task(name: "CachingTask") do
          required :name, type: :string

          define_method :call do
            # Access the parameter multiple times to test caching
            first_access = name
            second_access = name
            context.first_name = first_access
            context.second_name = second_access
            context.same_object = first_access.equal?(second_access)
          end
        end
      end

      it "caches parameter values to avoid re-evaluation" do
        result = task_class.call(name: "John")

        expect(result).to be_success
        expect(result.context.first_name).to eq("John")
        expect(result.context.second_name).to eq("John")
        expect(result.context.same_object).to be(true)
      end
    end
  end
end

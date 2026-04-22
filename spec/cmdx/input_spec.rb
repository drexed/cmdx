# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Input do
  describe "#initialize" do
    it "coerces name to a symbol and freezes children/options" do
      child = described_class.new(:child)
      input = described_class.new("user", children: [child], required: true)

      expect(input.name).to eq(:user)
      expect(input.children).to eq([child]).and be_frozen
      expect(input.instance_variable_get(:@options)).to be_frozen
    end

    it "defaults children to an empty array" do
      expect(described_class.new(:x).children).to eq([])
    end
  end

  describe "simple option accessors" do
    it "returns configured options" do
      input = described_class.new(
        :user,
        description: "desc",
        as: :member,
        prefix: "p_",
        suffix: "_s",
        source: :params,
        default: 1,
        transform: :upcase,
        if: :if?,
        unless: :unless?
      )

      expect(input).to have_attributes(
        description: "desc",
        as: :member,
        prefix: "p_",
        suffix: "_s",
        source: :params,
        default: 1,
        transform: :upcase,
        condition_if: :if?,
        condition_unless: :unless?,
        required: false
      )
    end

    it "description falls back to :desc" do
      expect(described_class.new(:user, desc: "short").description).to eq("short")
    end

    it "source defaults to :context" do
      expect(described_class.new(:user).source).to eq(:context)
    end
  end

  describe "#accessor_name" do
    it "returns :as when explicitly given" do
      expect(described_class.new(:user, as: :member).accessor_name).to eq(:member)
    end

    it "applies string prefix and suffix" do
      input = described_class.new(:id, prefix: "user_", suffix: "_val")
      expect(input.accessor_name).to eq(:user_id_val)
    end

    it "uses source_ prefix when prefix is true" do
      input = described_class.new(:id, source: :params, prefix: true)
      expect(input.accessor_name).to eq(:params_id)
    end

    it "uses _source suffix when suffix is true" do
      input = described_class.new(:id, source: :params, suffix: true)
      expect(input.accessor_name).to eq(:id_params)
    end

    it "returns the bare name by default" do
      expect(described_class.new(:id).accessor_name).to eq(:id)
    end
  end

  describe "#ivar_name" do
    it "is built from the accessor name" do
      expect(described_class.new(:user).ivar_name).to eq(:@_input_user)
      expect(described_class.new(:user, as: :member).ivar_name).to eq(:@_input_member)
    end
  end

  describe "#required?" do
    let(:task) do
      Class.new do
        def active? = true
        def inactive? = false
      end.new
    end

    it "is false when not required" do
      expect(described_class.new(:a).required?).to be(false)
    end

    it "is true without a task when required" do
      expect(described_class.new(:a, required: true).required?).to be(true)
    end

    it "evaluates if/unless guards against the task" do
      expect(described_class.new(:a, required: true, if: :active?).required?(task)).to be(true)
      expect(described_class.new(:a, required: true, if: :inactive?).required?(task)).to be(false)
      expect(described_class.new(:a, required: true, unless: :active?).required?(task)).to be(false)
    end
  end

  describe "#to_h" do
    it "exposes a serializable view" do
      child = described_class.new(:inner)
      input = described_class.new(:user, description: "d", required: true, children: [child])

      expect(input.to_h).to eq(
        name: :user,
        description: "d",
        required: true,
        options: { description: "d", required: true },
        children: [child.to_h]
      )
    end
  end

  describe "#as_json" do
    it "returns to_h" do
      input = described_class.new(:user, description: "d", required: true)
      expect(input.as_json).to eq(input.to_h)
    end
  end

  describe "#to_json" do
    it "emits a JSON string with the schema shape" do
      child = described_class.new(:inner)
      input = described_class.new(:user, description: "d", required: true, children: [child])

      parsed = JSON.parse(input.to_json)

      expect(parsed).to include(
        "name" => "user",
        "description" => "d",
        "required" => true
      )
      expect(parsed["options"]).to include("description" => "d", "required" => true)
      expect(parsed["children"]).to eq([JSON.parse(child.to_json)])
    end
  end

  describe "#resolve" do
    context "when the value is present in context" do
      it "returns the coerced value" do
        task_class = create_task_class(name: "ResolveTask") do
          required :age, coerce: :integer
        end
        task = task_class.new
        task.context.age = "42"

        input = described_class.new(:age, coerce: :integer, required: true)
        expect(input.resolve(task)).to eq(42)
      end
    end

    context "when the value is absent and required" do
      it "adds a missing error on the task" do
        task_class = create_task_class(name: "MissingInputTask")
        task = task_class.new

        input = described_class.new(:age, required: true)
        input.resolve(task)

        expect(task.errors[:age]).to include(CMDx::I18nProxy.t("cmdx.attributes.required"))
      end
    end

    context "when the value is absent but has a default" do
      it "applies a literal default" do
        task_class = create_task_class(name: "DefaultLiteralTask")
        task = task_class.new

        input = described_class.new(:level, default: 7)
        expect(input.resolve(task)).to eq(7)
      end

      it "applies a Symbol default by sending to the task" do
        task_class = create_task_class(name: "DefaultSymTask") do
          define_method(:default_level) { 99 }
        end
        task = task_class.new

        input = described_class.new(:level, default: :default_level)
        expect(input.resolve(task)).to eq(99)
      end

      it "applies a Proc default via instance_exec" do
        task_class = create_task_class(name: "DefaultProcTask") do
          define_method(:boost) { 5 }
        end
        task = task_class.new

        input = described_class.new(:level, default: proc { boost })
        expect(input.resolve(task)).to eq(5)
      end
    end

    context "with a transform" do
      it "applies a Symbol transform on the value" do
        task_class = create_task_class(name: "TransformTask")
        task = task_class.new
        task.context.name = "alice"

        input = described_class.new(:name, transform: :upcase)
        expect(input.resolve(task)).to eq("ALICE")
      end

      it "applies a Proc transform" do
        task_class = create_task_class(name: "TransformProcTask")
        task = task_class.new
        task.context.name = "alice"

        input = described_class.new(:name, transform: proc { |v| "#{v}!" })
        expect(input.resolve(task)).to eq("alice!")
      end

      it "applies a callable transform with the value and task" do
        task_class = create_task_class(name: "TransformCallableTask")
        task = task_class.new
        task.context.name = "alice"

        received = nil
        callable = Class.new do
          define_method(:call) do |value, t|
            received = t
            value.upcase
          end
        end.new

        input = described_class.new(:name, transform: callable)
        expect(input.resolve(task)).to eq("ALICE")
        expect(received).to be(task)
      end
    end

    context "with a Proc source" do
      it "calls the proc via instance_exec and treats the result as present" do
        task_class = create_task_class(name: "ProcSourceTask")
        task = task_class.new

        input = described_class.new(:computed, source: proc { 123 })
        expect(input.resolve(task)).to eq(123)
      end
    end

    context "with a Symbol source pointing to a hash method" do
      it "fetches by the input name" do
        task_class = create_task_class(name: "SymSourceTask") do
          define_method(:params) { { name: "alice" } }
        end
        task = task_class.new

        input = described_class.new(:name, source: :params)
        expect(input.resolve(task)).to eq("alice")
      end

      it "treats missing key as not provided" do
        task_class = create_task_class(name: "SymSourceMissingTask") do
          define_method(:params) { {} }
        end
        task = task_class.new

        input = described_class.new(:name, source: :params, default: "fallback")
        expect(input.resolve(task)).to eq("fallback")
      end
    end
  end

  describe "#resolve_from_parent" do
    let(:task_class) { create_task_class(name: "ParentTask") }
    let(:task) { task_class.new }

    it "fetches by name from a hash-like parent" do
      input = described_class.new(:age)
      expect(input.resolve_from_parent({ age: 30 }, task)).to eq(30)
    end

    it "falls back to string key lookup" do
      input = described_class.new(:age)
      expect(input.resolve_from_parent({ "age" => 30 }, task)).to eq(30)
    end

    it "returns nil for non-indexable parent values" do
      input = described_class.new(:age)
      expect(input.resolve_from_parent(Object.new, task)).to be_nil
    end

    it "treats nil parent as absent (no required error when not required)" do
      input = described_class.new(:age)
      expect(input.resolve_from_parent(nil, task)).to be_nil
      expect(task.errors).to be_empty
    end
  end
end

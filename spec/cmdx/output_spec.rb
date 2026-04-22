# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Output do
  describe "#initialize" do
    it "coerces the name to a symbol" do
      expect(described_class.new("user").name).to eq(:user)
    end

    it "freezes the options hash" do
      output = described_class.new(:user, required: true)
      expect(output.instance_variable_get(:@options)).to be_frozen
    end
  end

  describe "#description" do
    it "prefers :description over :desc" do
      output = described_class.new(:user, description: "full", desc: "short")
      expect(output.description).to eq("full")
    end

    it "falls back to :desc" do
      expect(described_class.new(:user, desc: "fallback").description).to eq("fallback")
    end

    it "is nil when neither is set" do
      expect(described_class.new(:user).description).to be_nil
    end
  end

  describe "#condition_if / #condition_unless" do
    it "returns the guard options" do
      output = described_class.new(:user, if: :active?, unless: :inactive?)
      expect(output.condition_if).to eq(:active?)
      expect(output.condition_unless).to eq(:inactive?)
    end
  end

  describe "#required" do
    it "defaults to false" do
      expect(described_class.new(:user).required).to be(false)
    end

    it "reflects the :required option" do
      expect(described_class.new(:user, required: true).required).to be(true)
    end
  end

  describe "simple option accessors" do
    it "exposes :default and :transform" do
      output = described_class.new(:level, default: 7, transform: :upcase)
      expect(output).to have_attributes(default: 7, transform: :upcase)
    end

    it "returns nil when unset" do
      output = described_class.new(:level)
      expect(output).to have_attributes(default: nil, transform: nil)
    end
  end

  describe "#required?" do
    it "is false when not required" do
      expect(described_class.new(:user).required?).to be(false)
    end

    it "is true when required and no task is given" do
      expect(described_class.new(:user, required: true).required?).to be(true)
    end

    context "with a task" do
      let(:task_class) do
        Class.new do
          def active? = true
          def inactive? = false
        end
      end
      let(:task) { task_class.new }

      it "is false when the if-guard is false" do
        output = described_class.new(:user, required: true, if: :inactive?)
        expect(output.required?(task)).to be(false)
      end

      it "is false when the unless-guard is true" do
        output = described_class.new(:user, required: true, unless: :active?)
        expect(output.required?(task)).to be(false)
      end

      it "is true when guards pass" do
        output = described_class.new(:user, required: true, if: :active?)
        expect(output.required?(task)).to be(true)
      end
    end
  end

  describe "#to_h" do
    it "returns name, description, required, and the raw options" do
      output = described_class.new(:user, description: "d", required: true, type: :string)

      expect(output.to_h).to eq(
        name: :user,
        description: "d",
        required: true,
        options: { description: "d", required: true, type: :string },
        children: []
      )
    end

    it "serializes children recursively" do
      child = described_class.new(:id, type: :integer)
      output = described_class.new(:user, children: [child], type: :hash)

      expect(output.to_h[:children]).to eq([child.to_h])
    end
  end

  describe "#verify" do
    let(:task) do
      create_task_class(name: "OutVerifyTask") do
        output :user, required: true
      end.new
    end

    it "adds a missing error when required and the context key is absent" do
      task.class.outputs.registry[:user].verify(task)

      expect(task.errors[:user]).to include(CMDx::I18nProxy.t("cmdx.outputs.missing"))
    end

    it "coerces and stores the value when the key is present" do
      task_class = create_task_class(name: "CoerceTask") do
        output :count, coerce: :integer
      end
      task = task_class.new
      task.context[:count] = "42"

      task_class.outputs.registry[:count].verify(task)

      expect(task.context[:count]).to eq(42)
    end

    it "does not modify context when the key is absent and not required" do
      task_class = create_task_class(name: "OptionalTask") do
        output :note
      end
      task = task_class.new

      task_class.outputs.registry[:note].verify(task)

      expect(task.context).to be_empty
      expect(task.errors).to be_empty
    end

    context "with :default" do
      it "applies a literal default when the key is absent" do
        task_class = create_task_class(name: "OutDefaultLiteral") do
          output :version, default: "v2"
        end
        task = task_class.new

        task_class.outputs.registry[:version].verify(task)

        expect(task.context[:version]).to eq("v2")
      end

      it "applies a Symbol default by sending to the task" do
        task_class = create_task_class(name: "OutDefaultSym") do
          output :version, default: :default_version
          define_method(:default_version) { "v3" }
        end
        task = task_class.new

        task_class.outputs.registry[:version].verify(task)

        expect(task.context[:version]).to eq("v3")
      end

      it "applies a Proc default via instance_exec" do
        task_class = create_task_class(name: "OutDefaultProc") do
          output :version, default: proc { "v#{algo_version}" }
          define_method(:algo_version) { 4 }
        end
        task = task_class.new

        task_class.outputs.registry[:version].verify(task)

        expect(task.context[:version]).to eq("v4")
      end

      it "applies a callable default with the task" do
        callable = Class.new do
          def call(task)
            "v-#{task.object_id}"
          end
        end.new
        task_class = create_task_class(name: "OutDefaultCallable") do
          output :version, default: callable
        end
        task = task_class.new

        task_class.outputs.registry[:version].verify(task)

        expect(task.context[:version]).to eq("v-#{task.object_id}")
      end

      it "applies default when the task wrote nil" do
        task_class = create_task_class(name: "OutDefaultNilWrite") do
          output :version, default: "v2"
        end
        task = task_class.new
        task.context[:version] = nil

        task_class.outputs.registry[:version].verify(task)

        expect(task.context[:version]).to eq("v2")
      end

      it "satisfies :required when the default produces a value" do
        task_class = create_task_class(name: "OutDefaultRequired") do
          output :version, required: true, default: "v2"
        end
        task = task_class.new

        task_class.outputs.registry[:version].verify(task)

        expect(task.errors).to be_empty
        expect(task.context[:version]).to eq("v2")
      end

      it "flows through coercion and validation" do
        task_class = create_task_class(name: "OutDefaultCoerced") do
          output :retention_days, default: "7", coerce: :integer
        end
        task = task_class.new

        task_class.outputs.registry[:retention_days].verify(task)

        expect(task.context[:retention_days]).to eq(7)
      end
    end

    context "with :transform" do
      it "applies a Symbol transform on the value" do
        task_class = create_task_class(name: "OutTransformSym") do
          output :email, transform: :downcase
        end
        task = task_class.new
        task.context[:email] = "Alice@Example.COM"

        task_class.outputs.registry[:email].verify(task)

        expect(task.context[:email]).to eq("alice@example.com")
      end

      it "falls back to the task when value doesn't respond" do
        task_class = create_task_class(name: "OutTransformTaskMethod") do
          output :name, transform: :shout
          define_method(:shout) { |v| "#{v}!!!" }
        end
        task = task_class.new
        task.context[:name] = 42

        task_class.outputs.registry[:name].verify(task)

        expect(task.context[:name]).to eq("42!!!")
      end

      it "resolves a private method on the value" do
        klass = Class.new do
          def initialize(v) = (@v = v)

          private

          def squish = @v.gsub(/\s+/, " ").strip
        end

        task_class = create_task_class(name: "OutTransformPrivate") do
          output :line, transform: :squish
        end
        task = task_class.new
        task.context[:line] = klass.new("  hi  there ")

        task_class.outputs.registry[:line].verify(task)

        expect(task.context[:line]).to eq("hi there")
      end

      it "applies a Proc transform via instance_exec" do
        task_class = create_task_class(name: "OutTransformProc") do
          output :tags, transform: proc { |v| v.uniq.sort }
        end
        task = task_class.new
        task.context[:tags] = %w[b a a c]

        task_class.outputs.registry[:tags].verify(task)

        expect(task.context[:tags]).to eq(%w[a b c])
      end

      it "applies a callable transform with (value, task)" do
        callable = Class.new do
          def call(value, _task)
            value.to_s.upcase
          end
        end.new
        task_class = create_task_class(name: "OutTransformCallable") do
          output :code, transform: callable
        end
        task = task_class.new
        task.context[:code] = "abc"

        task_class.outputs.registry[:code].verify(task)

        expect(task.context[:code]).to eq("ABC")
      end

      it "runs after coerce and before validation" do
        task_class = create_task_class(name: "OutTransformPipeline") do
          output :days, coerce: :integer, transform: proc { |v| v.clamp(1, 5) },
            numeric: { min: 1, max: 5 }
        end
        task = task_class.new
        task.context[:days] = "42"

        task_class.outputs.registry[:days].verify(task)

        expect(task.context[:days]).to eq(5)
        expect(task.errors).to be_empty
      end
    end

    context "with nested children" do
      it "verifies required children against the parent value" do
        task_class = create_task_class(name: "OutChildRequired") do
          output :user do
            required :id
            optional :email
          end
        end
        task = task_class.new
        task.context[:user] = { email: "x@y" }

        task_class.outputs.registry[:user].verify(task)

        expect(task.errors[:id]).to include(CMDx::I18nProxy.t("cmdx.outputs.missing"))
      end

      it "skips child verification when parent is nil" do
        task_class = create_task_class(name: "OutChildSkip") do
          output :user do
            required :id
          end
        end
        task = task_class.new

        task_class.outputs.registry[:user].verify(task)

        expect(task.errors).to be_empty
      end

      it "validates child values against the parent" do
        task_class = create_task_class(name: "OutChildValidate") do
          output :user do
            required :age, coerce: :integer, numeric: { min: 18 }
          end
        end
        task = task_class.new
        task.context[:user] = { age: "12" }

        task_class.outputs.registry[:user].verify(task)

        expect(task.errors.keys).to include(:age)
      end
    end
  end
end

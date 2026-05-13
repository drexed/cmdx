# frozen_string_literal: true

RSpec.describe CMDx::Output do
  describe "#initialize" do
    it "coerces the name to a symbol" do
      expect(described_class.new("user").name).to eq(:user)
    end

    it "freezes the options hash" do
      output = described_class.new(:user, default: 1)
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

  describe "#default" do
    it "exposes the :default option" do
      expect(described_class.new(:level, default: 7).default).to eq(7)
    end

    it "is nil when unset" do
      expect(described_class.new(:level).default).to be_nil
    end
  end

  describe "#to_h" do
    it "returns name, description, and the raw options" do
      output = described_class.new(:user, description: "d", default: "x")

      expect(output.to_h).to eq(
        name: :user,
        description: "d",
        options: { description: "d", default: "x" }
      )
    end
  end

  describe "#as_json" do
    it "returns to_h" do
      output = described_class.new(:user, description: "d")
      expect(output.as_json).to eq(output.to_h)
    end
  end

  describe "#to_json" do
    it "emits a JSON string with the schema shape" do
      output = described_class.new(:user, description: "d")

      parsed = JSON.parse(output.to_json)

      expect(parsed).to include(
        "name" => "user",
        "description" => "d"
      )
      expect(parsed["options"]).to include("description" => "d")
    end
  end

  describe "#verify" do
    it "adds a missing error when the context key is absent" do
      task_class = create_task_class(name: "OutVerifyTask") do
        output :user
      end
      task = task_class.new

      task_class.outputs.registry[:user].verify(task)

      expect(task.errors[:user]).to include(CMDx::I18nProxy.t("cmdx.outputs.missing"))
    end

    it "writes the value back when the key is present" do
      task_class = create_task_class(name: "WritebackTask") do
        output :note
      end
      task = task_class.new
      task.context[:note] = "hello"

      task_class.outputs.registry[:note].verify(task)

      expect(task.context[:note]).to eq("hello")
      expect(task.errors).to be_empty
    end

    it "treats an explicit nil context value as set" do
      task_class = create_task_class(name: "OutNilSet") do
        output :note
      end
      task = task_class.new
      task.context[:note] = nil

      task_class.outputs.registry[:note].verify(task)

      expect(task.errors).to be_empty
    end

    context "with :if / :unless" do
      it "skips verification when :if is false" do
        task_class = create_task_class(name: "OutIfFalse") do
          output :user, if: :inactive?
          define_method(:inactive?) { false }
        end
        task = task_class.new

        task_class.outputs.registry[:user].verify(task)

        expect(task.errors).to be_empty
      end

      it "skips verification when :unless is true" do
        task_class = create_task_class(name: "OutUnlessTrue") do
          output :user, unless: :active?
          define_method(:active?) { true }
        end
        task = task_class.new

        task_class.outputs.registry[:user].verify(task)

        expect(task.errors).to be_empty
      end

      it "runs verification when guards pass" do
        task_class = create_task_class(name: "OutGuardsPass") do
          output :user, if: :active?
          define_method(:active?) { true }
        end
        task = task_class.new

        task_class.outputs.registry[:user].verify(task)

        expect(task.errors[:user]).to include(CMDx::I18nProxy.t("cmdx.outputs.missing"))
      end
    end

    context "with :default" do
      it "applies a literal default when the key is absent" do
        task_class = create_task_class(name: "OutDefaultLiteral") do
          output :version, default: "v2"
        end
        task = task_class.new

        task_class.outputs.registry[:version].verify(task)

        expect(task.context[:version]).to eq("v2")
        expect(task.errors).to be_empty
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
    end
  end
end

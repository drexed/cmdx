# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task output verification", type: :feature do
  describe "required outputs" do
    context "when all declared keys are set" do
      subject(:result) do
        create_task_class(name: "AllOutputsSet") do
          output :user, :token, required: true
          define_method(:work) do
            context.user = "alice"
            context.token = "abc123"
          end
        end.execute
      end

      it "succeeds with no errors" do
        expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
        expect(result.errors).to be_empty
      end
    end

    context "when one required key is missing" do
      subject(:result) do
        create_task_class(name: "OneMissing") do
          output :user, :token, required: true
          define_method(:work) { context.user = "alice" }
        end.execute
      end

      it "fails with an error only for the missing key" do
        expect(result.errors.to_h).to eq(token: ["must be set in the context"])
      end
    end

    context "when multiple required keys are missing" do
      subject(:result) do
        create_task_class(name: "MultiMissing") do
          output :user, :token, :session, required: true
          define_method(:work) { context.user = "alice" }
        end.execute
      end

      it "collects errors for every missing key" do
        expect(result.errors.to_h).to eq(
          token: ["must be set in the context"],
          session: ["must be set in the context"]
        )
      end
    end

    context "when a required key is set to nil" do
      subject(:result) do
        create_task_class(name: "NilValue") do
          output :user, required: true
          define_method(:work) { context.user = nil }
        end.execute
      end

      it "succeeds because the key exists" do
        expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
      end
    end
  end

  describe "non-required outputs" do
    it "succeeds even when the key is missing" do
      task = create_task_class(name: "OptionalOutputs") do
        output :user, :token
        define_method(:work) { context.user = "alice" }
      end

      expect(task.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
    end
  end

  describe "skipped/failed outcomes" do
    it "does not verify outputs when the task skips" do
      task = create_task_class(name: "SkipOutputs") do
        output :user, required: true
        define_method(:work) { skip!("not needed") }
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::SKIPPED)
      expect(result.errors).to be_empty
    end

    it "does not verify outputs when the task fails" do
      task = create_task_class(name: "FailOutputs") do
        output :user, required: true
        define_method(:work) { fail!("broken") }
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::FAILED, reason: "broken")
      expect(result.errors).to be_empty
    end
  end

  describe "inheritance" do
    let(:parent) do
      create_task_class(name: "ParentOutputs") do
        output :user, required: true
      end
    end

    it "inherits parent outputs alongside its own" do
      child = create_task_class(base: parent, name: "ChildOutputs") do
        output :token, required: true
        define_method(:work) do
          context.user = "alice"
          context.token = "abc"
        end
      end

      expect(child.outputs.registry.keys).to contain_exactly(:user, :token)
      expect(child.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
    end

    it "fails when a parent-declared output is missing in the child" do
      child = create_task_class(base: parent, name: "MissingParent") do
        output :token, required: true
        define_method(:work) { context.token = "abc" }
      end

      expect(child.execute.errors.to_h).to eq(user: ["must be set in the context"])
    end

    it "removes inherited outputs via deregister" do
      child = create_task_class(base: parent, name: "NoParent") do
        deregister :output, :user
        define_method(:work) { nil }
      end

      expect(child.execute).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(child.outputs.registry).not_to have_key(:user)
    end
  end

  describe "defaults" do
    it "fills in a required output via default when work doesn't set it" do
      task = create_task_class(name: "DefaultVersion") do
        output :version, required: true, default: "v2"
        define_method(:work) { nil }
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(result.context.version).to eq("v2")
    end

    it "lets work override the default when it sets a value" do
      task = create_task_class(name: "DefaultOverridden") do
        output :version, default: "v2"
        define_method(:work) { context.version = "v3" }
      end

      expect(task.execute.context.version).to eq("v3")
    end

    it "applies the default when work explicitly writes nil" do
      task = create_task_class(name: "DefaultNilWrite") do
        output :version, default: "v2"
        define_method(:work) { context.version = nil }
      end

      expect(task.execute.context.version).to eq("v2")
    end

    it "flows defaults through coercion" do
      task = create_task_class(name: "DefaultCoerced") do
        output :retention_days, default: "7", coerce: :integer
        define_method(:work) { nil }
      end

      expect(task.execute.context.retention_days).to eq(7)
    end
  end

  describe "transform" do
    it "normalizes values the task wrote" do
      task = create_task_class(name: "TransformEmail") do
        output :email, coerce: :string, transform: :downcase
        define_method(:work) { context.email = "Alice@Example.COM" }
      end

      expect(task.execute.context.email).to eq("alice@example.com")
    end

    it "runs after coerce and before validation" do
      task = create_task_class(name: "TransformClamp") do
        output :days, coerce: :integer, transform: proc { |v| v.clamp(1, 5) },
          numeric: { min: 1, max: 5 }
        define_method(:work) { context.days = "42" }
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::SUCCESS)
      expect(result.context.days).to eq(5)
    end
  end

  describe "blocking execute!" do
    it "raises a Fault for a missing required output" do
      task = create_task_class(name: "BangOutput") do
        output :user, required: true
        define_method(:work) { nil }
      end

      expect { task.execute! }.to raise_error(CMDx::Fault, "user must be set in the context")
    end
  end
end

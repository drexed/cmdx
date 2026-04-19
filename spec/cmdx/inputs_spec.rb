# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Inputs do
  subject(:inputs) { described_class.new }

  let(:task_class) { create_task_class(name: "InputsTask") }

  describe "#initialize" do
    it "starts with an empty registry" do
      expect(inputs).to be_empty
      expect(inputs.registry).to eq({})
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      inputs.register(task_class, :a)
      copy = inputs.dup

      copy.register(task_class, :b)

      expect(inputs.size).to eq(1)
      expect(copy.size).to eq(2)
    end
  end

  describe "#register" do
    it "adds an Input per name and defines an accessor on the task class" do
      inputs.register(task_class, :user, :token, required: true)

      expect(inputs.size).to eq(2)
      expect(inputs.registry[:user]).to be_a(CMDx::Input)
      expect(inputs.registry[:user].required).to be(true)
      expect(task_class.instance_method(:user)).to be_a(UnboundMethod)
      expect(task_class.instance_method(:token)).to be_a(UnboundMethod)
    end

    it "returns self" do
      expect(inputs.register(task_class, :user)).to be(inputs)
    end

    it "attaches nested children built via the DSL" do
      inputs.register(task_class, :profile) do
        required :email
        optional :name
      end

      profile = inputs.registry[:profile]
      expect(profile.children.map(&:name)).to eq(%i[email name])
      expect(profile.children.map(&:required)).to eq([true, false])
    end

    it "raises when the accessor name collides with an existing instance method" do
      expect { inputs.register(task_class, :context) }
        .to raise_error(CMDx::DefinitionError, /:context.*already defined/)
    end

    it "raises when re-registering an input with the same accessor name" do
      inputs.register(task_class, :user)

      expect { inputs.register(task_class, :user) }
        .to raise_error(CMDx::DefinitionError, /:user.*already defined/)
    end

    it "raises when a nested child collides with an existing method" do
      expect do
        inputs.register(task_class, :profile) do
          required :context
        end
      end.to raise_error(CMDx::DefinitionError, /:context.*already defined/)
    end
  end

  describe "#deregister" do
    it "removes the Input and undefines the accessor" do
      inputs.register(task_class, :user)
      inputs.deregister(task_class, :user)

      expect(inputs.registry).to be_empty
      expect(task_class.method_defined?(:user)).to be(false)
    end
  end

  describe "#resolve" do
    it "assigns ivars from the context based on each Input" do
      inputs.register(task_class, :age, coerce: :integer)

      task = task_class.new
      task.context.age = "99"
      inputs.resolve(task)

      expect(task.instance_variable_get(:@_input_age)).to eq(99)
    end

    it "records required errors when values are missing" do
      inputs.register(task_class, :age, required: true)

      task = task_class.new
      inputs.resolve(task)

      expect(task.errors[:age]).not_to be_empty
    end

    it "resolves nested children from the parent value" do
      inputs.register(task_class, :profile) do
        required :email
      end

      task = task_class.new
      task.context.profile = { email: "x@y.com" }
      inputs.resolve(task)

      expect(task.instance_variable_get(:@_input_email)).to eq("x@y.com")
    end

    it "skips nested resolution when the parent value is nil" do
      inputs.register(task_class, :profile) do
        required :email
      end

      task = task_class.new
      inputs.resolve(task)

      expect(task.instance_variable_defined?(:@_input_email)).to be(false)
    end
  end

  describe "ChildBuilder DSL" do
    let(:children) do
      CMDx::Inputs::ChildBuilder.build do
        required :a
        optional :b
        input :c
      end
    end

    it "flags required and optional entries" do
      expect(children.map(&:name)).to eq(%i[a b c])
      expect(children.map(&:required)).to eq([true, false, false])
    end

    it "supports nesting" do
      children = CMDx::Inputs::ChildBuilder.build do
        required :outer do
          required :inner
        end
      end

      expect(children.first.children.map(&:name)).to eq([:inner])
    end

    it "freezes the built children list" do
      expect(children).to be_frozen
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Outputs do
  subject(:outputs) { described_class.new }

  describe "#initialize" do
    it "starts with an empty registry" do
      expect(outputs).to be_empty
      expect(outputs.registry).to eq({})
    end
  end

  describe "#initialize_copy" do
    it "dups the registry" do
      outputs.register(:user)
      copy = outputs.dup

      copy.register(:extra)

      expect(outputs.size).to eq(1)
      expect(copy.size).to eq(2)
    end
  end

  describe "#register" do
    it "adds each key as an Output entry and returns self" do
      expect(outputs.register(:user, :token, description: "x")).to be(outputs)

      expect(outputs.size).to eq(2)
      expect(outputs.registry[:user]).to be_a(CMDx::Output)
      expect(outputs.registry[:user].description).to eq("x")
    end

    it "overwrites an existing entry with the same name" do
      outputs.register(:user, default: "a")
      outputs.register(:user, default: "b")

      expect(outputs.registry[:user].default).to eq("b")
      expect(outputs.size).to eq(1)
    end
  end

  describe "#deregister" do
    it "removes the given keys and returns self" do
      outputs.register(:user, :token)
      expect(outputs.deregister(:user)).to be(outputs)

      expect(outputs.registry).to have_key(:token)
      expect(outputs.registry).not_to have_key(:user)
    end

    it "accepts string keys" do
      outputs.register(:user)
      outputs.deregister("user")
      expect(outputs).to be_empty
    end

    it "is a no-op for unknown keys" do
      expect { outputs.deregister(:missing) }.not_to raise_error
    end
  end

  describe "#empty? / #size" do
    it "track registry state" do
      expect(outputs).to be_empty

      outputs.register(:a, :b)
      expect(outputs).not_to be_empty
      expect(outputs.size).to eq(2)
    end
  end

  describe "#verify" do
    it "invokes verify on each registered Output" do
      task_class = create_task_class(name: "VerifyAllTask") do
        output :user
        output :token
      end
      task = task_class.new

      task_class.outputs.verify(task)

      expect(task.errors.keys).to contain_exactly(:user, :token)
    end
  end
end

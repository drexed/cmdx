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
      expect(outputs.register(:user, :token, required: true)).to be(outputs)

      expect(outputs.size).to eq(2)
      expect(outputs.registry[:user]).to be_a(CMDx::Output)
      expect(outputs.registry[:user].required).to be(true)
    end

    it "overwrites an existing entry with the same name" do
      outputs.register(:user, required: false)
      outputs.register(:user, required: true)

      expect(outputs.registry[:user].required).to be(true)
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
        output :user, required: true
        output :token, required: true
      end
      task = task_class.new

      task_class.outputs.verify(task)

      expect(task.errors.keys).to contain_exactly(:user, :token)
    end
  end

  describe "nested outputs" do
    it "builds child outputs from a block" do
      outputs.register(:user) do
        required :id, type: :integer
        optional :email
      end

      user = outputs.registry[:user]
      expect(user.children.map(&:name)).to eq(%i[id email])
      expect(user.children.first.required).to be(true)
      expect(user.children.last.required).to be(false)
    end

    it "supports arbitrary nesting" do
      outputs.register(:user) do
        output :address do
          required :city
        end
      end

      address = outputs.registry[:user].children.first
      expect(address.name).to eq(:address)
      expect(address.children.map(&:name)).to eq([:city])
    end

    it "freezes the children list" do
      outputs.register(:user) { required :id }
      expect(outputs.registry[:user].children).to be_frozen
    end

    it "exposes children through to_h (schema export)" do
      outputs.register(:user) do
        required :id
      end

      schema = outputs.registry[:user].to_h
      expect(schema[:children].first).to include(name: :id, required: true)
    end
  end
end

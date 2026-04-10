# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ValueResolver do
  let(:context) { CMDx::Context.new(raw_email: " A@B.C ", other: 99) }

  describe ".source" do
    it "reads from context[attr.name] when :from is not set" do
      attr = CMDx::Attribute.new(:raw_email, :string)
      task = Object.new
      expect(described_class.source(attr, task, context)).to eq(" A@B.C ")
    end

    it "reads from context[attr.from] when :from is set and task does not define that method" do
      attr = CMDx::Attribute.new(:email, :string, from: :other)
      task = Object.new
      expect(described_class.source(attr, task, context)).to eq(99)
    end

    it "calls the task method when :from matches a method (including private)" do
      task = Class.new do
        def user_id
          42
        end
        private :user_id
      end.new

      attr = CMDx::Attribute.new(:id, :integer, from: :user_id)
      ctx = CMDx::Context.new({})
      expect(described_class.source(attr, task, ctx)).to eq(42)
    end
  end

  describe ".derive" do
    it "returns the value unchanged when derive is nil" do
      attr = CMDx::Attribute.new(:x)
      expect(described_class.derive(attr, Object.new, 1)).to eq(1)
    end

    it "calls a derive callable with the sourced value" do
      task = Object.new
      attr = CMDx::Attribute.new(:x, derive: ->(v) { v.to_s.strip.downcase })
      expect(described_class.derive(attr, task, " AbC ")).to eq("abc")
    end

    it "supports callables that respond to #call" do
      doubler = Class.new do
        def call(v)
          v * 2
        end
      end.new
      task = Object.new
      attr = CMDx::Attribute.new(:x, derive: doubler)
      expect(described_class.derive(attr, task, 3)).to eq(6)
    end
  end

  describe ".apply_default" do
    it "returns the value when it is not nil" do
      attr = CMDx::Attribute.new(:x, default: 1)
      expect(described_class.apply_default(attr, Object.new, 0)).to eq(0)
    end

    it "returns the literal default when value is nil" do
      attr = CMDx::Attribute.new(:x, default: "fallback")
      expect(described_class.apply_default(attr, Object.new, nil)).to eq("fallback")
    end

    it "evaluates Proc defaults in the task instance" do
      task = Class.new do
        def multiplier
          3
        end
      end.new
      attr = CMDx::Attribute.new(:x, default: -> { multiplier * 2 })
      expect(described_class.apply_default(attr, task, nil)).to eq(6)
    end

    it "dispatches Symbol defaults to the task" do
      task = Class.new do
        def default_name
          "computed"
        end
      end.new
      attr = CMDx::Attribute.new(:x, default: :default_name)
      expect(described_class.apply_default(attr, task, nil)).to eq("computed")
    end
  end

  describe ".coerce" do
    it "returns the value when type is nil" do
      attr = CMDx::Attribute.new(:x)
      expect(described_class.coerce(attr, "1")).to eq("1")
    end

    it "returns nil without coercing when value is nil" do
      attr = CMDx::Attribute.new(:x, :integer)
      expect(described_class.coerce(attr, nil)).to be_nil
    end

    it "runs the registered coercion for the attribute type" do
      attr = CMDx::Attribute.new(:x, :integer)
      expect(described_class.coerce(attr, "42")).to eq(42)
    end
  end

  describe ".transform" do
    it "returns the value when transform is nil" do
      attr = CMDx::Attribute.new(:x)
      expect(described_class.transform(attr, Object.new, 1)).to eq(1)
    end

    it "invokes the transform callable with the coerced value" do
      task = Object.new
      attr = CMDx::Attribute.new(:x, transform: ->(v) { v.to_s.upcase })
      expect(described_class.transform(attr, task, :ab)).to eq("AB")
    end
  end

  describe ".call" do
    it "runs source → derive → default → coerce → transform" do
      task = Class.new do
        def default_offset
          1
        end
      end.new

      attr = CMDx::Attribute.new(
        :n,
        :integer,
        required: false,
        default: :default_offset,
        derive: ->(v) { v }, # keep nil so default applies
        transform: ->(v) { v + 100 }
      )

      ctx = CMDx::Context.new(n: "5")
      expect(described_class.call(attr, task, ctx)).to eq(105)

      ctx_nil = CMDx::Context.new(n: nil)
      expect(described_class.call(attr, task, ctx_nil)).to eq(101)
    end

    it "applies derive before coercion" do
      attr = CMDx::Attribute.new(:n, :integer, required: false, derive: ->(v) { v.to_s.strip })
      expect(described_class.call(attr, Object.new, CMDx::Context.new(n: " 7 "))).to eq(7)
    end
  end
end

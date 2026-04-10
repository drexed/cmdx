# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  describe ".execute and .execute!" do
    let(:ok_task) do
      Class.new(described_class) do
        def work
          ctx[:out] = 1
        end
      end
    end

    let(:fail_task) do
      Class.new(described_class) do
        def work
          fail!("bad", halt: true)
        end
      end
    end

    let(:skip_task) do
      Class.new(described_class) do
        def work
          skip!("nope", halt: true)
        end
      end
    end

    it ".execute returns a Result" do
      r = ok_task.execute
      expect(r).to be_a(CMDx::Result)
      expect(r).to be_frozen
      expect(r.success?).to be(true)
    end

    it ".execute! raises FailFault on failure" do
      expect { fail_task.execute! }.to raise_error(CMDx::FailFault) do |e|
        expect(e.result.failed?).to be(true)
      end
    end

    it ".execute! raises SkipFault on skip" do
      expect { skip_task.execute! }.to raise_error(CMDx::SkipFault) do |e|
        expect(e.result.skipped?).to be(true)
      end
    end
  end

  describe ".type" do
    it "returns formatted class name" do
      k = Class.new(described_class) do
        def self.name
          "MyApp::DoThing"
        end

        def work; end
      end
      expect(k.type).to eq("myapp.dothing")
    end
  end

  describe ".task_settings and .settings" do
    it ".task_settings returns Settings" do
      k = Class.new(described_class) { def work; end }
      expect(k.task_settings).to be_a(CMDx::Settings)
    end

    it ".settings yields Settings for configuration" do
      k = Class.new(described_class) { def work; end }
      seen = nil
      s = k.settings do |st|
        seen = st
        st.tags = [:a]
      end
      expect(seen).to be_a(CMDx::Settings)
      expect(s.resolved_tags).to eq([:a])
    end
  end

  describe "instance behavior" do
    let(:concrete) do
      Class.new(described_class) do
        def work
          ctx[:ran] = true
        end
      end
    end

    it "#work raises UndefinedMethodError when not overridden" do
      k = Class.new(described_class)
      task = k.allocate
      task.instance_variable_set(:@context, CMDx::Context.new)
      task.instance_variable_set(:@_attributes, {})
      task.send(:initialize)
      expect { task.work }.to raise_error(CMDx::UndefinedMethodError, /#work/)
    end

    it "#context and #ctx return the context" do
      r = concrete.execute(foo: 2)
      expect(r.context[:foo]).to eq(2)
    end

    it "#logger returns a Logger" do
      t = concrete.allocate
      t.instance_variable_set(:@context, CMDx::Context.new)
      t.instance_variable_set(:@_attributes, {})
      expect(t.logger).to be_a(Logger)
    end
  end

  describe "attribute DSL" do
    let(:attr_task) do
      Class.new(described_class) do
        required :name, :string
        optional :age, :integer

        def work
          ctx[:label] = "#{name}-#{age}"
        end
      end
    end

    it "supports .required, .optional, .attribute, .remove_attribute, .attributes_schema" do
      k = Class.new(described_class) do
        attribute :x, :string, required: false
        def work; end
      end
      expect(k.attributes_schema).to have_key(:x)
      k.remove_attribute(:x)
      expect(k.attributes_schema).not_to have_key(:x)
    end

    it "validates and exposes coerced attributes" do
      r = attr_task.execute(name: "ann", age: "3")
      expect(r.success?).to be(true)
      expect(r.context[:label]).to eq("ann-3")
    end
  end

  describe "callback DSL" do
    it "registers on_success, on_failed, before_validation, etc." do
      log = []
      k = Class.new(described_class) do
        required :n, :integer

        before_validation { log << :bv }
        before_execution { log << :be }
        on_success { log << :os }
        on_failed { log << :of }

        def work
          fail!("x", halt: true) if n.negative?
        end
      end

      k.execute(n: 1)
      expect(log).to eq(%i[bv be os])

      log.clear
      k.execute(n: -1)
      expect(log).to include(:bv, :be, :of)
    end
  end

  describe "middleware DSL" do
    it ".register and .deregister wrap execution" do
      wrapper = Module.new do
        def self.call(task, *)
          task.ctx[:mw] = (task.ctx[:mw] || 0) + 1
          yield
        end
      end
      k = Class.new(described_class) do
        register wrapper

        def work; end
      end
      expect(k.execute.context[:mw]).to eq(1)
      k.deregister(wrapper)
      expect(k.execute.context[:mw]).to be_nil
    end
  end

  describe "returns DSL" do
    it ".returns and .remove_returns verify context keys" do
      k = Class.new(described_class) do
        returns :needed
        def work; end
      end
      r = k.execute
      expect(r.failed?).to be(true)

      k.remove_returns(:needed)
      expect(k.execute.success?).to be(true)
    end
  end

  describe "inheritance" do
    let(:parent) do
      Class.new(described_class) do
        settings { |s| s.tags = [:p] }
        required :a, :string
        def work; end
      end
    end

    it "child inherits settings and registries" do
      child = Class.new(parent) do
        optional :b, :string
        def work
          ctx[:ab] = "#{a}#{b}"
        end
      end
      expect(child.task_settings.parent).to eq(parent.task_settings)
      expect(child.attributes_schema).to have_key(:a)
      r = child.execute(a: "1", b: "2")
      expect(r.success?).to be(true)
      expect(r.context[:ab]).to eq("12")
    end
  end
end

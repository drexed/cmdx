# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task deprecation", type: :feature do
  def deprecated_task(value, **options, &)
    create_task_class(name: "DeprecatedTask") do
      deprecation value, **options, &
      define_method(:work) { (context.executed ||= []) << :ran }
    end
  end

  describe "no deprecation declared" do
    it "is not deprecated" do
      expect(create_successful_task.execute).to have_attributes(deprecated?: false)
    end
  end

  describe "built-in modes" do
    it ":log still executes and marks as deprecated" do
      result = deprecated_task(:log).execute

      expect(result).to have_attributes(
        status: CMDx::Signal::SUCCESS,
        deprecated?: true,
        context: have_attributes(executed: %i[ran])
      )
    end

    it ":warn calls Kernel.warn and still executes" do
      expect(Kernel).to receive(:warn).with(/DEPRECATED/)

      expect(deprecated_task(:warn).execute).to have_attributes(
        status: CMDx::Signal::SUCCESS,
        deprecated?: true
      )
    end

    it ":error raises before work runs, under execute" do
      task = deprecated_task(:error)

      expect { task.execute }.to raise_error(CMDx::DeprecationError, /is deprecated and prohibited from execution/)
    end

    it ":error raises under execute! as well" do
      expect { deprecated_task(:error).execute! }.to raise_error(CMDx::DeprecationError)
    end
  end

  describe "callable forms" do
    it "runs a block in the task's instance context" do
      task = create_task_class(name: "BlockDep") do
        deprecation { context.block_ran = true }
        define_method(:work) { (context.executed ||= []) << :ran }
      end

      expect(task.execute.context).to have_attributes(block_ran: true, executed: %i[ran])
    end

    it "invokes a Proc with the task instance" do
      seen = nil
      callable = ->(t) { seen = t.class.name }

      deprecated_task(callable).execute

      expect(seen).to match(/DeprecatedTask/)
    end

    it "resolves a Symbol via an instance method" do
      task = create_task_class(name: "SymbolDep") do
        deprecation :resolve_mode
        define_method(:work) { nil }
        define_method(:resolve_mode) { :handled }
      end

      expect(task.execute).to have_attributes(deprecated?: true)
    end

    it "raises ArgumentError for an unsupported value" do
      task = deprecated_task(Object.new)

      expect { task.execute }.to raise_error(ArgumentError, /Symbol, Proc, or respond to #call/)
    end
  end

  describe "conditional gating" do
    it "if: truthy activates" do
      task = create_task_class(name: "IfTruthy") do
        deprecation :log, if: :legacy?
        define_method(:work) { nil }
        define_method(:legacy?) { true }
      end

      expect(task.execute).to have_attributes(deprecated?: true)
    end

    it "if: falsy skips" do
      task = create_task_class(name: "IfFalsy") do
        deprecation :log, if: :legacy?
        define_method(:work) { nil }
        define_method(:legacy?) { false }
      end

      expect(task.execute).to have_attributes(deprecated?: false)
    end

    it "unless: falsy activates" do
      task = create_task_class(name: "UnlessFalsy") do
        deprecation :log, unless: :modern?
        define_method(:work) { nil }
        define_method(:modern?) { false }
      end

      expect(task.execute).to have_attributes(deprecated?: true)
    end

    it "unless: truthy skips" do
      task = create_task_class(name: "UnlessTruthy") do
        deprecation :log, unless: :modern?
        define_method(:work) { nil }
        define_method(:modern?) { true }
      end

      expect(task.execute).to have_attributes(deprecated?: false)
    end

    it "Proc conditions evaluate in the task context" do
      task = create_task_class(name: "ProcCond") do
        deprecation :log, if: proc { respond_to?(:work) }
        define_method(:work) { nil }
      end

      expect(task.execute).to have_attributes(deprecated?: true)
    end
  end

  describe "inheritance" do
    let(:parent) do
      create_task_class(name: "ParentDep") do
        deprecation :log
        define_method(:work) { nil }
      end
    end

    it "child inherits parent deprecation" do
      child = create_task_class(base: parent, name: "ChildDep") { define_method(:work) { nil } }

      expect(child.deprecation).to be(parent.deprecation)
      expect(child.execute).to have_attributes(deprecated?: true)
    end

    it "child can override with its own deprecation" do
      child = create_task_class(base: parent, name: "OverrideDep") do
        deprecation :warn
        define_method(:work) { nil }
      end

      expect(Kernel).to receive(:warn).with(/DEPRECATED/)

      child.execute
    end
  end

  describe "telemetry" do
    it "emits :task_deprecated before :error halts execution" do
      events = []
      task = create_task_class(name: "DeprecatedErrorTelemetry") do
        deprecation :error
        telemetry.subscribe(:task_deprecated) { |e| events << e }
        define_method(:work) { nil }
      end

      expect { task.execute }.to raise_error(CMDx::DeprecationError)
      expect(events.size).to eq(1)
    end

    it "does not emit when conditions gate the deprecation" do
      events = []
      task = create_task_class(name: "DepGated") do
        deprecation :log, if: -> { false }
        telemetry.subscribe(:task_deprecated) { |e| events << e }
        define_method(:work) { nil }
      end

      task.execute

      expect(events).to be_empty
    end
  end

  describe "result integration" do
    it "surfaces deprecated: true in result#to_h" do
      expect(deprecated_task(:log).execute.to_h).to include(deprecated: true)
    end
  end
end

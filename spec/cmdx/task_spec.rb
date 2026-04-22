# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  describe "class-level registries" do
    let(:base) { create_task_class(name: "BaseTask") }
    let(:child) { create_task_class(base:, name: "ChildTask") }

    it "inherits settings from the superclass" do
      base.settings(tags: %w[root])

      expect(child.settings.tags).to eq(%w[root])
    end

    it "settings with options builds a new Settings layer" do
      base.settings(tags: %w[root])
      child.settings(tags: %w[extra])
      expect(child.settings.tags).to eq(%w[extra])
      expect(base.settings.tags).to eq(%w[root])
    end

    it "middlewares inherits from the superclass" do
      mw = ->(_t, &blk) { blk.call }
      base.register(:middleware, mw)

      expect(child.middlewares.registry.map(&:first)).to include(mw)
    end

    it "callbacks/telemetry/coercions/validators are dup-isolated per subclass" do
      base.callbacks
      child.callbacks
      expect(child.callbacks).not_to be(base.callbacks)
    end
  end

  describe "retry_on" do
    it "defaults to a new Retry with no exceptions" do
      klass = create_task_class
      expect(klass.retry_on).to be_a(CMDx::Retry)
    end

    it "adds exceptions when called with them" do
      klass = create_task_class
      err = Class.new(StandardError)
      klass.retry_on(err, limit: 2)

      expect(klass.retry_on.exceptions).to include(err)
      expect(klass.retry_on.limit).to eq(2)
    end
  end

  describe "#register / #deregister" do
    it "dispatches to the right registry" do
      klass = create_task_class
      mw = ->(_t, &blk) { blk.call }
      klass.register(:middleware, mw)
      expect(klass.middlewares.registry.map(&:first)).to include(mw)

      klass.deregister(:middleware, mw)
      expect(klass.middlewares.registry.map(&:first)).not_to include(mw)
    end

    it "raises on an unknown registry type" do
      klass = create_task_class
      expect { klass.register(:bogus) }.to raise_error(ArgumentError, "unknown registry type: :bogus")
      expect { klass.deregister(:bogus) }.to raise_error(ArgumentError, "unknown registry type: :bogus")
    end
  end

  describe "#deprecation" do
    it "returns nil without a setting" do
      expect(create_task_class.deprecation).to be_nil
    end

    it "stores a new Deprecation when given a value" do
      klass = create_task_class
      klass.deprecation(:log)
      expect(klass.deprecation).to be_a(CMDx::Deprecation)
    end

    it "inherits from the superclass when unset on the subclass" do
      parent = create_task_class(name: "DeprecatedParent")
      parent.deprecation(:log)
      child = create_task_class(base: parent, name: "DeprecatedChild")

      expect(child.deprecation).to be(parent.deprecation)
    end
  end

  describe "#inputs / #outputs and their schemas" do
    let(:klass) do
      create_task_class(name: "SchemaTask") do
        required :name
        optional :age
        output :id, required: true
      end
    end

    it "inputs_schema returns a flat hash of input descriptors" do
      expect(klass.inputs_schema.keys).to eq(%i[name age])
      expect(klass.inputs_schema[:name][:required]).to be(true)
      expect(klass.inputs_schema[:age][:required]).to be(false)
    end

    it "outputs_schema returns a flat hash of output descriptors" do
      expect(klass.outputs_schema.keys).to eq([:id])
      expect(klass.outputs_schema[:id][:required]).to be(true)
    end
  end

  describe "#type" do
    it "is 'Task' by default" do
      expect(create_task_class.type).to eq("Task")
    end

    it "is 'Workflow' when the class includes Workflow" do
      klass = create_workflow_class
      expect(klass.type).to eq("Workflow")
    end
  end

  describe ".execute / .execute!" do
    it "execute returns a result for successful tasks" do
      expect(create_successful_task.execute).to be_success
    end

    it "execute returns a failed result when the task fails" do
      expect(create_failing_task(reason: "x").execute).to be_failed
    end

    it "execute! raises on failure" do
      expect { create_failing_task(reason: "x").execute! }.to raise_error(CMDx::Fault, "x")
    end

    it "yields the result when given a block" do
      received = nil
      create_successful_task.execute { |r| received = r }
      expect(received).to be_success
    end

    it "is aliased as .call" do
      expect(create_successful_task.call).to be_success
    end
  end

  describe "#execute" do
    it "returns a result for a successful task" do
      task = create_successful_task.new

      expect(task.execute).to be_success
    end

    it "returns a failed result with strict: false (default)" do
      task = create_failing_task(reason: "x").new

      expect(task.execute).to be_failed
    end

    it "raises a Fault with strict: true on failure" do
      task = create_failing_task(reason: "x").new

      expect { task.execute(strict: true) }.to raise_error(CMDx::Fault, "x")
    end

    it "does not raise with strict: true on success" do
      task = create_successful_task.new

      expect(task.execute(strict: true)).to be_success
    end

    it "yields the result to the block and returns the block's value" do
      task = create_successful_task.new
      received = nil
      returned = task.execute do |r|
        received = r
        :from_block
      end

      expect(received).to be_success
      expect(returned).to eq(:from_block)
    end

    it "is aliased as #call" do
      task = create_successful_task.new

      expect(task.call).to be_success
    end
  end

  describe "#initialize" do
    it "builds a Context and an empty Errors" do
      task = create_task_class.new(a: 1)

      expect(task.context).to be_a(CMDx::Context)
      expect(task.context[:a]).to eq(1)
      expect(task.errors).to be_a(CMDx::Errors)
      expect(task.errors).to be_empty
    end

    it "wraps a hash as Context" do
      task = create_task_class.new(b: 2)
      expect(task.context.to_h).to include(b: 2)
    end
  end

  describe "#work" do
    it "raises ImplementationError for the base definition" do
      task = create_task_class.new
      expect { task.work }.to raise_error(CMDx::ImplementationError, /undefined method/)
    end
  end

  describe "signal throwers" do
    let(:klass) { create_task_class }

    it "success! throws a success signal" do
      task = klass.new
      signal = catch(CMDx::Signal::TAG) { task.send(:success!, "ok", foo: 1) }

      expect(signal).to have_attributes(status: "success", reason: "ok", metadata: { foo: 1 })
    end

    it "skip! throws a skipped signal" do
      task = klass.new
      signal = catch(CMDx::Signal::TAG) { task.send(:skip!, "later") }

      expect(signal.status).to eq("skipped")
    end

    it "fail! throws a failed signal with backtrace" do
      task = klass.new
      signal = catch(CMDx::Signal::TAG) { task.send(:fail!, "bad") }

      expect(signal.status).to eq("failed")
      expect(signal.backtrace).to be_an(Array)
      expect(signal.backtrace).not_to be_empty
    end

    it "throw! echoes another failed signal" do
      source = CMDx::Signal.failed("upstream")
      task = klass.new
      signal = catch(CMDx::Signal::TAG) { task.send(:throw!, source) }

      expect(signal.reason).to eq("upstream")
      expect(signal.status).to eq("failed")
    end

    it "throw! is a no-op for non-failed signals" do
      source = CMDx::Signal.success
      task = klass.new
      result = catch(CMDx::Signal::TAG) do
        task.send(:throw!, source)
        :not_thrown
      end

      expect(result).to eq(:not_thrown)
    end

    it "raises FrozenError when the task is frozen" do
      task = klass.new
      task.freeze

      expect { task.send(:success!) }.to raise_error(FrozenError, "cannot throw signals")
      expect { task.send(:fail!) }.to raise_error(FrozenError)
      expect { task.send(:skip!) }.to raise_error(FrozenError)
      expect { task.send(:throw!, CMDx::Signal.failed) }.to raise_error(FrozenError)
    end
  end

  describe "#logger" do
    it "memoizes a LoggerProxy-backed logger" do
      task = create_task_class.new
      first = task.logger
      second = task.logger
      expect(first).to be(second)
    end
  end
end

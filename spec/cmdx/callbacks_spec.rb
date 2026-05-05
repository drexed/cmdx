# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Callbacks do
  subject(:callbacks) { described_class.new }

  describe "#initialize" do
    it "starts with an empty registry" do
      expect(callbacks.registry).to eq({})
      expect(callbacks).to be_empty
    end
  end

  describe "#initialize_copy" do
    it "deep-copies each event's callable list" do
      callbacks.register(:on_success, :hook)
      copy = callbacks.dup

      copy.register(:on_success, :extra)

      expect(callbacks.registry[:on_success].map(&:first)).to eq([:hook])
      expect(copy.registry[:on_success].map(&:first)).to eq(%i[hook extra])
      expect(copy.registry[:on_success]).not_to equal(callbacks.registry[:on_success])
    end
  end

  describe "#register" do
    context "with a Symbol" do
      it "appends to the event registry and returns self" do
        expect(callbacks.register(:on_success, :hook)).to be(callbacks)
        expect(callbacks.registry[:on_success]).to eq([[:hook, {}]])
      end
    end

    context "with a callable" do
      it "stores the callable object" do
        callable = ->(_task) {}
        callbacks.register(:on_success, callable)

        expect(callbacks.registry[:on_success]).to eq([[callable, {}]])
      end
    end

    context "with a block" do
      it "stores the block as a Proc" do
        block = proc {}
        callbacks.register(:on_success, &block)

        expect(callbacks.registry[:on_success]).to eq([[block, {}]])
      end
    end

    context "with conditional options" do
      it "captures :if and :unless gates alongside the callback" do
        callbacks.register(:on_success, :hook, if: :ready?, unless: :busy?)

        callable, options = callbacks.registry[:on_success].first
        expect(callable).to eq(:hook)
        expect(options).to eq(if: :ready?, unless: :busy?)
      end
    end

    context "when registering the same event multiple times" do
      it "preserves insertion order" do
        callable = ->(_task) {}
        callbacks.register(:on_success, :first)
        callbacks.register(:on_success, callable)
        callbacks.register(:on_success) { :third }

        entries = callbacks.registry[:on_success].map(&:first)
        expect(entries.size).to eq(3)
        expect(entries[0]).to eq(:first)
        expect(entries[1]).to be(callable)
        expect(entries[2]).to be_a(Proc)
      end
    end

    context "when both callable and block are given" do
      it "raises ArgumentError" do
        expect do
          callbacks.register(:on_success, :hook) { :block }
        end.to raise_error(ArgumentError, "provide either a callable or a block, not both")
      end
    end

    context "when the callback is not a Symbol and does not respond to call" do
      it "raises ArgumentError" do
        expect do
          callbacks.register(:on_success, "not callable")
        end.to raise_error(ArgumentError, "callback must be a Symbol or respond to #call")
      end
    end

    context "when neither callable nor block is given" do
      it "raises ArgumentError" do
        expect do
          callbacks.register(:on_success)
        end.to raise_error(ArgumentError, "callback must be a Symbol or respond to #call")
      end
    end

    context "when the event is unknown" do
      it "raises ArgumentError listing valid events" do
        expect do
          callbacks.register(:on_bogus, :hook)
        end.to raise_error(ArgumentError, /unknown event :on_bogus, must be one of/)
      end
    end
  end

  describe "#deregister" do
    it "removes the event's callbacks and returns self" do
      callbacks.register(:on_success, :hook)

      expect(callbacks.deregister(:on_success)).to be(callbacks)
      expect(callbacks.registry).not_to have_key(:on_success)
    end

    it "is a no-op when the event has no registrations" do
      expect { callbacks.deregister(:on_success) }.not_to raise_error
      expect(callbacks.registry).to eq({})
    end

    context "when the event is unknown" do
      it "raises ArgumentError" do
        expect do
          callbacks.deregister(:on_bogus)
        end.to raise_error(ArgumentError, /unknown event :on_bogus/)
      end
    end

    context "with a specific callable" do
      it "removes only entries matching the Symbol method name" do
        callbacks.register(:on_success, :hook)
        callbacks.register(:on_success, :other)

        callbacks.deregister(:on_success, :hook)

        expect(callbacks.registry[:on_success].map(&:first)).to eq([:other])
      end

      it "removes a class-level callable by reference" do
        handler = Class.new { def self.call(_); end }
        callbacks.register(:on_success, handler)
        callbacks.register(:on_success, :other)

        callbacks.deregister(:on_success, handler)

        expect(callbacks.registry[:on_success].map(&:first)).to eq([:other])
      end

      it "removes a Proc/Lambda by identity" do
        lambda_cb = ->(_t) {}
        proc_cb = proc {}
        callbacks.register(:on_success, lambda_cb)
        callbacks.register(:on_success, proc_cb)

        callbacks.deregister(:on_success, lambda_cb)

        expect(callbacks.registry[:on_success].map(&:first)).to eq([proc_cb])
      end

      it "removes every duplicate registration of the same callable" do
        callbacks.register(:on_success, :hook)
        callbacks.register(:on_success, :hook)
        callbacks.register(:on_success, :other)

        callbacks.deregister(:on_success, :hook)

        expect(callbacks.registry[:on_success].map(&:first)).to eq([:other])
      end

      it "drops the event key when the last matching entry is removed" do
        callbacks.register(:on_success, :hook)

        callbacks.deregister(:on_success, :hook)

        expect(callbacks.registry).not_to have_key(:on_success)
      end

      it "is a no-op when the callable is not registered" do
        callbacks.register(:on_success, :hook)

        callbacks.deregister(:on_success, :missing)

        expect(callbacks.registry[:on_success].map(&:first)).to eq([:hook])
      end

      it "is a no-op when the event has no registrations" do
        expect { callbacks.deregister(:on_success, :hook) }.not_to raise_error
        expect(callbacks.registry).to eq({})
      end

      it "still raises ArgumentError when the event is unknown" do
        expect do
          callbacks.deregister(:on_bogus, :hook)
        end.to raise_error(ArgumentError, /unknown event :on_bogus/)
      end

      it "returns self for chaining" do
        callbacks.register(:on_success, :hook)
        expect(callbacks.deregister(:on_success, :hook)).to be(callbacks)
      end
    end
  end

  describe "#empty?" do
    it "is true when nothing is registered" do
      expect(callbacks).to be_empty
    end

    it "is false after a registration" do
      callbacks.register(:on_success, :hook)
      expect(callbacks).not_to be_empty
    end

    it "is true again after deregistering the only event" do
      callbacks.register(:on_success, :hook)
      callbacks.deregister(:on_success)

      expect(callbacks).to be_empty
    end
  end

  describe "#size" do
    it "returns the number of distinct events with registrations" do
      callbacks.register(:on_success, :a)
      callbacks.register(:on_success, :b)
      callbacks.register(:on_failed, :c)

      expect(callbacks.size).to eq(2)
    end
  end

  describe "#count" do
    it "returns the total number of callbacks across all events" do
      callbacks.register(:on_success, :a)
      callbacks.register(:on_success, :b)
      callbacks.register(:on_failed, :c)

      expect(callbacks.count).to eq(3)
    end

    it "returns zero when nothing is registered" do
      expect(callbacks.count).to eq(0)
    end
  end

  describe "#process" do
    let(:task_class) do
      Class.new do
        attr_reader :calls

        def initialize
          @calls = []
        end

        def do_work
          @calls << :do_work
        end
      end
    end
    let(:task) { task_class.new }

    it "returns nil when no callbacks are registered for the event" do
      expect(callbacks.process(:on_success, task)).to be_nil
    end

    context "with a Symbol callback" do
      it "sends the method on the task" do
        callbacks.register(:on_success, :do_work)
        callbacks.process(:on_success, task)

        expect(task.calls).to eq([:do_work])
      end
    end

    context "with a Proc callback" do
      it "runs the proc via instance_exec and passes the task as the argument" do
        received = []
        callbacks.register(:on_success, proc { |t| received << [self, t] })

        callbacks.process(:on_success, task)

        expect(received.size).to eq(1)
        receiver, arg = received.first
        expect(receiver).to be(task)
        expect(arg).to be(task)
      end
    end

    context "with a class-level callable" do
      it "invokes #call with the task" do
        handler = Class.new do
          class << self

            attr_reader :received

            def call(task)
              (@received ||= []) << task
            end

          end
        end
        callbacks.register(:on_success, handler)

        callbacks.process(:on_success, task)

        expect(handler.received).to eq([task])
      end
    end

    context "with multiple callbacks for the same event" do
      it "invokes them in registration order" do
        sequence = []
        callbacks.register(:on_success, :do_work)
        callbacks.register(:on_success, proc { sequence << :proc })
        callbacks.register(:on_success, ->(_t) { sequence << :lambda })

        callbacks.process(:on_success, task)

        expect(task.calls).to eq([:do_work])
        expect(sequence).to eq(%i[proc lambda])
      end
    end

    context "when the event has no callbacks" do
      it "does not invoke any task method" do
        callbacks.register(:on_failed, :do_work)
        callbacks.process(:on_success, task)

        expect(task.calls).to be_empty
      end
    end

    context "with conditional gates" do
      let(:gated_task_class) do
        Class.new do
          attr_reader :calls
          attr_accessor :ready, :busy

          def initialize
            @calls = []
            @ready = true
            @busy = false
          end

          def ready? = ready
          def busy? = busy

          def do_work
            @calls << :do_work
          end
        end
      end
      let(:task) { gated_task_class.new }

      it "runs the callback when :if evaluates truthy" do
        callbacks.register(:on_success, :do_work, if: :ready?)
        callbacks.process(:on_success, task)

        expect(task.calls).to eq([:do_work])
      end

      it "skips the callback when :if evaluates falsy" do
        task.ready = false
        callbacks.register(:on_success, :do_work, if: :ready?)
        callbacks.process(:on_success, task)

        expect(task.calls).to be_empty
      end

      it "skips the callback when :unless evaluates truthy" do
        task.busy = true
        callbacks.register(:on_success, :do_work, unless: :busy?)
        callbacks.process(:on_success, task)

        expect(task.calls).to be_empty
      end

      it "supports a Proc gate evaluated against the task (self = task)" do
        callbacks.register(:on_success, :do_work, if: proc { ready })
        callbacks.process(:on_success, task)

        expect(task.calls).to eq([:do_work])
      end

      it "supports a callable gate invoked with the task" do
        gate = Class.new do
          def self.call(task) = task.ready
        end
        callbacks.register(:on_success, :do_work, if: gate)
        callbacks.process(:on_success, task)

        expect(task.calls).to eq([:do_work])
      end

      it "skips a Proc/callable gate's callback when it evaluates falsy" do
        callbacks.register(:on_success, :do_work, if: proc { false })
        callbacks.process(:on_success, task)

        expect(task.calls).to be_empty
      end

      it "evaluates :if and :unless together (both must pass)" do
        callbacks.register(:on_success, :do_work, if: :ready?, unless: :busy?)
        callbacks.process(:on_success, task)
        expect(task.calls).to eq([:do_work])

        task.busy = true
        task.calls.clear
        callbacks.process(:on_success, task)
        expect(task.calls).to be_empty
      end
    end
  end

  describe "#around" do
    let(:task_class) do
      Class.new do
        attr_reader :calls

        def initialize
          @calls = []
        end

        def wrap_with_log
          @calls << :before
          yield
          @calls << :after
        end
      end
    end
    let(:task) { task_class.new }

    it "yields the inner block when no callbacks are registered" do
      ran = false
      callbacks.around(:around_execution, task) { ran = true }

      expect(ran).to be(true)
    end

    it "invokes a Symbol callback whose method yields" do
      callbacks.register(:around_execution, :wrap_with_log)
      callbacks.around(:around_execution, task) { task.calls << :inner }

      expect(task.calls).to eq(%i[before inner after])
    end

    it "invokes a Proc callback with (task, continuation)" do
      callbacks.register(:around_execution, proc { |t, cont|
        t.calls << :before
        cont.call
        t.calls << :after
      })
      callbacks.around(:around_execution, task) { task.calls << :inner }

      expect(task.calls).to eq(%i[before inner after])
    end

    it "invokes a class-level callable with (task, continuation)" do
      handler = Class.new do
        def self.call(task, continuation)
          task.calls << :before
          continuation.call
          task.calls << :after
        end
      end
      callbacks.register(:around_execution, handler)
      callbacks.around(:around_execution, task) { task.calls << :inner }

      expect(task.calls).to eq(%i[before inner after])
    end

    it "nests multiple callbacks in declaration order (outer first)" do
      callbacks.register(:around_execution, proc { |t, cont|
        t.calls << :outer_before
        cont.call
        t.calls << :outer_after
      })
      callbacks.register(:around_execution, proc { |t, cont|
        t.calls << :inner_before
        cont.call
        t.calls << :inner_after
      })
      callbacks.around(:around_execution, task) { task.calls << :body }

      expect(task.calls).to eq(%i[outer_before inner_before body inner_after outer_after])
    end

    it "skips a link whose :if gate evaluates falsy but still runs the body" do
      callbacks.register(:around_execution, :wrap_with_log, if: proc { false })
      callbacks.around(:around_execution, task) { task.calls << :inner }

      expect(task.calls).to eq(%i[inner])
    end

    it "raises CallbackError when the callback never invokes its continuation" do
      callbacks.register(:around_execution, proc { |_t, _cont| :noop })

      expect do
        callbacks.around(:around_execution, task) { :unreached }
      end.to raise_error(CMDx::CallbackError, /around_execution callback did not invoke its continuation/)
    end
  end

  describe "EVENTS" do
    it "is frozen" do
      expect(described_class::EVENTS).to be_frozen
    end

    it "includes :around_execution" do
      expect(described_class::EVENTS).to include(:around_execution)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::MiddlewareRegistry do
  subject(:registry) { described_class.new }

  let(:task) { create_simple_task(name: "TestTask").new }

  let(:simple_middleware) do
    Class.new do
      def initialize(*args, **kwargs, &block)
        @args = args
        @kwargs = kwargs
        @block = block
      end

      def call(task, next_callable)
        task.context.middleware_calls ||= []
        task.context.middleware_calls << :simple
        next_callable.call(task)
      end
    end
  end

  let(:blocking_middleware) do
    Class.new do
      def call(task, _next_callable)
        task.context.middleware_calls ||= []
        task.context.middleware_calls << :blocking
        "blocked"
      end
    end
  end

  let(:middleware_instance) do
    double("MiddlewareInstance").tap do |instance|
      allow(instance).to receive(:call) do |task, next_callable|
        task.context.middleware_calls ||= []
        task.context.middleware_calls << :instance
        next_callable.call(task)
      end
    end
  end

  describe ".new" do
    it "initializes with empty registry by default" do
      expect(registry.registry).to eq({})
    end

    it "initializes with provided registry hash" do
      initial_registry = { simple_middleware => [[], {}, nil] }
      registry = described_class.new(initial_registry)

      expect(registry.registry).to eq(initial_registry)
    end

    it "converts non-hash input to hash" do
      registry = described_class.new([])

      expect(registry.registry).to eq({})
    end
  end

  describe "#register" do
    it "registers middleware class without arguments" do
      registry.register(simple_middleware)

      expect(registry.registry[simple_middleware]).to eq([[], {}, nil])
    end

    it "registers middleware with positional arguments" do
      registry.register(simple_middleware, :arg1, :arg2)

      expect(registry.registry[simple_middleware]).to eq([%i[arg1 arg2], {}, nil])
    end

    it "registers middleware with keyword arguments" do
      registry.register(simple_middleware, timeout: 30, level: :debug)

      expect(registry.registry[simple_middleware]).to eq([[], { timeout: 30, level: :debug }, nil])
    end

    it "registers middleware with both positional and keyword arguments" do
      registry.register(simple_middleware, :arg1, timeout: 30)

      expect(registry.registry[simple_middleware]).to eq([[:arg1], { timeout: 30 }, nil])
    end

    it "registers middleware with block" do
      block = proc(&:id)
      registry.register(simple_middleware, &block)

      expect(registry.registry[simple_middleware]).to eq([[], {}, block])
    end

    it "registers middleware instance (non-class)" do
      registry.register(middleware_instance)

      expect(registry.registry[middleware_instance]).to eq([[], {}, nil])
    end

    it "returns self for method chaining" do
      result = registry.register(simple_middleware)
                       .register(blocking_middleware)

      expect(result).to eq(registry)
      expect(registry.registry).to include(simple_middleware, blocking_middleware)
    end

    it "overwrites existing middleware registration" do
      registry.register(simple_middleware, :original)
      registry.register(simple_middleware, :updated)

      expect(registry.registry[simple_middleware]).to eq([[:updated], {}, nil])
    end
  end

  describe "#call" do
    context "when no block is provided" do
      it "raises ArgumentError" do
        expect { registry.call(task) }.to raise_error(
          ArgumentError, "block required"
        )
      end
    end

    context "with empty registry" do
      it "executes block directly" do
        result = registry.call(task) { |_t| "executed" }

        expect(result).to eq("executed")
      end
    end

    context "with single middleware" do
      before { registry.register(simple_middleware) }

      it "executes middleware around block" do
        result = registry.call(task) do |t|
          t.context.executed = true
          "success"
        end

        expect(task.context.middleware_calls).to eq([:simple])
        expect(task.context.executed).to be true
        expect(result).to eq("success")
      end
    end

    context "with multiple middleware" do
      let(:first_middleware) do
        Class.new do
          def call(task, next_callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << :first
            next_callable.call(task)
          end
        end
      end

      let(:second_middleware) do
        Class.new do
          def call(task, next_callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << :second
            next_callable.call(task)
          end
        end
      end

      it "executes middleware in reverse registration order" do
        registry.register(first_middleware)
        registry.register(second_middleware)

        registry.call(task) { |t| t.context.executed = true }

        expect(task.context.middleware_calls).to eq(%i[first second])
        expect(task.context.executed).to be true
      end
    end

    context "with middleware that blocks execution" do
      before { registry.register(blocking_middleware) }

      it "prevents block execution when middleware doesn't call next" do
        result = registry.call(task) { |t| t.context.executed = true }

        expect(task.context.middleware_calls).to eq([:blocking])
        expect(task.context.executed).to be_nil
        expect(result).to eq("blocked")
      end
    end

    context "with middleware instance (non-class)" do
      before { registry.register(middleware_instance) }

      it "calls middleware instance directly" do
        result = registry.call(task) { |_t| "success" }

        expect(middleware_instance).to have_received(:call).with(task, anything)
        expect(task.context.middleware_calls).to eq([:instance])
        expect(result).to eq("success")
      end
    end

    context "with middleware requiring initialization arguments" do
      let(:configurable_middleware) do
        Class.new do
          def initialize(prefix, suffix: "")
            @prefix = prefix
            @suffix = suffix
          end

          def call(task, next_callable)
            task.context.middleware_calls ||= []
            task.context.middleware_calls << "#{@prefix}_middleware#{@suffix}"
            next_callable.call(task)
          end
        end
      end

      it "passes initialization arguments to middleware constructor" do
        registry.register(configurable_middleware, "test", suffix: "_configured")

        registry.call(task) { |t| t.context.executed = true }

        expect(task.context.middleware_calls).to eq(["test_middleware_configured"])
        expect(task.context.executed).to be true
      end
    end

    context "with middleware that modifies result" do
      let(:transform_middleware) do
        Class.new do
          def call(task, next_callable)
            result = next_callable.call(task)
            "transformed: #{result}"
          end
        end
      end

      it "allows middleware to transform the result" do
        registry.register(transform_middleware)

        result = registry.call(task) { |_t| "original" }

        expect(result).to eq("transformed: original")
      end
    end
  end

  describe "#to_h" do
    it "returns empty hash for empty registry" do
      expect(registry.to_h).to eq({})
    end

    it "returns deep copy of registry configurations" do
      args = %i[arg1 arg2]
      kwargs = { timeout: 30 }
      block = proc(&:id)

      registry.register(simple_middleware, *args, **kwargs, &block)
      result = registry.to_h

      expect(result[simple_middleware]).to eq([args, kwargs, block])
      expect(result[simple_middleware][0]).not_to be(args)
      expect(result[simple_middleware][1]).not_to be(kwargs)
      expect(result[simple_middleware][2]).to be(block)
    end

    it "handles multiple middleware configurations" do
      registry.register(simple_middleware, :arg1)
      registry.register(blocking_middleware, timeout: 10)

      result = registry.to_h

      expect(result).to include(
        simple_middleware => [[:arg1], {}, nil],
        blocking_middleware => [[], { timeout: 10 }, nil]
      )
    end

    it "preserves nil values in configurations" do
      registry.register(simple_middleware)
      result = registry.to_h

      expect(result[simple_middleware]).to eq([[], {}, nil])
    end
  end
end

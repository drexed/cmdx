# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::MiddlewareRegistry do
  subject(:registry) { described_class.new(initial_registry) }

  let(:initial_registry) { [] }
  let(:mock_task) { instance_double(CMDx::Task) }
  let(:mock_middleware1) { instance_double("Middleware1", call: nil) }
  let(:mock_middleware2) { instance_double("Middleware2", call: nil) }

  describe "#initialize" do
    context "when no registry is provided" do
      subject(:registry) { described_class.new }

      it "initializes with an empty array" do
        expect(registry.registry).to eq([])
      end
    end

    context "when a registry is provided" do
      let(:initial_registry) { [[mock_middleware1, {}]] }

      it "initializes with the provided registry" do
        expect(registry.registry).to eq([[mock_middleware1, {}]])
      end
    end
  end

  describe "#registry" do
    let(:initial_registry) { [[mock_middleware1, {}]] }

    it "returns the internal registry array" do
      expect(registry.registry).to eq([[mock_middleware1, {}]])
    end
  end

  describe "#to_a" do
    let(:initial_registry) { [[mock_middleware1, {}]] }

    it "returns the registry array" do
      expect(registry.to_a).to eq([[mock_middleware1, {}]])
    end

    it "is an alias for registry" do
      expect(registry.method(:to_a)).to eq(registry.method(:registry))
    end
  end

  describe "#dup" do
    let(:initial_registry) { [[mock_middleware1, { option: "value" }]] }

    it "returns a new MiddlewareRegistry instance" do
      duplicated = registry.dup

      expect(duplicated).to be_a(described_class)
      expect(duplicated).not_to be(registry)
    end

    it "duplicates the registry array and its elements" do
      duplicated = registry.dup

      expect(duplicated.registry).to eq(registry.registry)
      expect(duplicated.registry).not_to be(registry.registry)
      expect(duplicated.registry.first).not_to be(registry.registry.first)
    end

    it "allows independent modification of the duplicated registry" do
      duplicated = registry.dup

      duplicated.register(mock_middleware2)

      expect(duplicated.registry.size).to eq(2)
      expect(registry.registry.size).to eq(1)
    end

    context "when registry is empty" do
      let(:initial_registry) { [] }

      it "returns a new empty MiddlewareRegistry" do
        duplicated = registry.dup

        expect(duplicated.registry).to eq([])
        expect(duplicated).not_to be(registry)
      end
    end
  end

  describe "#register" do
    context "when registering middleware without options" do
      it "adds the middleware to the end of the registry" do
        registry.register(mock_middleware1)

        expect(registry.registry).to eq([[mock_middleware1, {}]])
      end

      it "returns self for method chaining" do
        result = registry.register(mock_middleware1)

        expect(result).to be(registry)
      end
    end

    context "when registering middleware with options" do
      let(:options) { { timeout: 30, retry: true } }

      it "stores the middleware with its options" do
        registry.register(mock_middleware1, **options)

        expect(registry.registry).to eq([[mock_middleware1, options]])
      end
    end

    context "when registering middleware at a specific position" do
      let(:initial_registry) { [[mock_middleware1, {}]] }

      it "inserts at the beginning when at: 0" do
        registry.register(mock_middleware2, at: 0)

        expect(registry.registry).to eq([[mock_middleware2, {}], [mock_middleware1, {}]])
      end

      it "inserts at a specific index" do
        registry.register(mock_middleware2, at: 1)

        expect(registry.registry).to eq([[mock_middleware1, {}], [mock_middleware2, {}]])
      end

      it "inserts at the end when at: -1 (default)" do
        registry.register(mock_middleware2, at: -1)

        expect(registry.registry).to eq([[mock_middleware1, {}], [mock_middleware2, {}]])
      end
    end

    context "when registering multiple middlewares" do
      it "maintains insertion order" do
        registry.register(mock_middleware1)
        registry.register(mock_middleware2)

        expect(registry.registry).to eq([
                                          [mock_middleware1, {}],
                                          [mock_middleware2, {}]
                                        ])
      end
    end

    context "when registering middleware with position and options" do
      let(:initial_registry) { [[mock_middleware1, {}]] }
      let(:options) { { timeout: 30 } }

      it "inserts at specified position with options" do
        registry.register(mock_middleware2, at: 0, **options)

        expect(registry.registry).to eq([
                                          [mock_middleware2, options],
                                          [mock_middleware1, {}]
                                        ])
      end
    end
  end

  describe "#call!" do
    let(:block_result) { "block_executed" }
    let(:test_block) { proc { |_task| block_result } }

    context "when no block is given" do
      it "raises ArgumentError" do
        expect { registry.call!(mock_task) }.to raise_error(ArgumentError, "block required")
      end
    end

    context "when registry is empty" do
      it "yields to the block immediately" do
        result = registry.call!(mock_task, &test_block)

        expect(result).to eq(block_result)
      end

      it "passes the task to the block" do
        yielded_task = nil
        registry.call!(mock_task) { |task| yielded_task = task }

        expect(yielded_task).to be(mock_task)
      end
    end

    context "when registry has one middleware" do
      before do
        registry.register(mock_middleware1)
      end

      it "calls the middleware with empty options by default" do
        allow(mock_middleware1).to receive(:call).and_yield

        registry.call!(mock_task, &test_block)

        expect(mock_middleware1).to have_received(:call).with(mock_task)
      end

      it "yields the result when middleware calls the block" do
        allow(mock_middleware1).to receive(:call).and_yield

        result = registry.call!(mock_task, &test_block)

        expect(result).to eq(block_result)
      end
    end

    context "when middleware is registered with options" do
      let(:options) { { timeout: 30, retry: true } }

      before do
        registry.register(mock_middleware1, **options)
      end

      it "passes options to the middleware" do
        allow(mock_middleware1).to receive(:call).and_yield

        registry.call!(mock_task, &test_block)

        expect(mock_middleware1).to have_received(:call).with(mock_task, **options)
      end
    end

    context "when registry has multiple middlewares" do
      before do
        registry.register(mock_middleware1)
        registry.register(mock_middleware2)
      end

      it "calls middlewares in order" do
        call_order = []
        allow(mock_middleware1).to receive(:call) do |_task, &block|
          call_order << :middleware1
          block.call
        end
        allow(mock_middleware2).to receive(:call) do |_task, &block|
          call_order << :middleware2
          block.call
        end

        registry.call!(mock_task) { call_order << :block }

        expect(call_order).to eq(%i[middleware1 middleware2 block])
      end

      it "passes the task through the middleware chain" do
        allow(mock_middleware1).to receive(:call).with(mock_task).and_yield
        allow(mock_middleware2).to receive(:call).with(mock_task).and_yield

        registry.call!(mock_task, &test_block)

        expect(mock_middleware1).to have_received(:call).with(mock_task)
        expect(mock_middleware2).to have_received(:call).with(mock_task)
      end

      it "returns the final result from the block" do
        allow(mock_middleware1).to receive(:call).and_yield
        allow(mock_middleware2).to receive(:call).and_yield

        result = registry.call!(mock_task, &test_block)

        expect(result).to eq(block_result)
      end
    end

    context "when middleware modifies the result" do
      let(:middleware_result) { "modified_result" }

      before do
        registry.register(mock_middleware1)
        allow(mock_middleware1).to receive(:call) do |_task, &block|
          block.call
          middleware_result
        end
      end

      it "returns the middleware's result" do
        result = registry.call!(mock_task, &test_block)

        expect(result).to eq(middleware_result)
      end
    end

    context "when middleware doesn't yield" do
      before do
        registry.register(mock_middleware1)
        allow(mock_middleware1).to receive(:call).and_return("middleware_stopped")
      end

      it "stops execution and returns middleware result" do
        block_called = false
        result = registry.call!(mock_task) { block_called = true }

        expect(block_called).to be(false)
        expect(result).to eq("middleware_stopped")
      end
    end

    context "when middleware raises an error" do
      before do
        registry.register(mock_middleware1)
        allow(mock_middleware1).to receive(:call).and_raise(StandardError, "middleware error")
      end

      it "propagates the error" do
        expect { registry.call!(mock_task, &test_block) }.to raise_error(StandardError, "middleware error")
      end
    end
  end
end

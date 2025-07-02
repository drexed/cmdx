# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::MiddlewareRegistry do
  subject(:registry) { described_class.new }

  let(:task) { double("Task") }
  let(:execution_block) { proc { |_t| "final_result" } }

  describe "Array behavior" do
    it "extends Array class" do
      expect(registry).to be_a(Array)
    end

    it "can store middleware definitions" do
      middleware_class = Class.new
      registry << [middleware_class, [], nil]

      expect(registry.size).to eq(1)
      expect(registry.first).to eq([middleware_class, [], nil])
    end

    it "supports array operations" do
      middleware1 = Class.new
      middleware2 = Class.new
      registry << [middleware1, [], nil]
      registry << [middleware2, [], nil]

      expect(registry.size).to eq(2)
      expect(registry.empty?).to be(false)
      expect(registry.first[0]).to eq(middleware1)
      expect(registry.last[0]).to eq(middleware2)
    end
  end

  describe "#use" do
    context "when adding middleware class without arguments" do
      let(:middleware_class) { Class.new }

      it "adds middleware to registry" do
        result = registry.use(middleware_class)

        expect(registry.size).to eq(1)
        expect(registry.first).to eq([middleware_class, [], nil])
        expect(result).to eq(registry)
      end
    end

    context "when adding middleware class with arguments" do
      let(:middleware_class) { Class.new }

      it "stores arguments with middleware" do
        registry.use(middleware_class, :arg1, :arg2, key: "value")

        expect(registry.size).to eq(1)
        expect(registry.first).to eq([middleware_class, [:arg1, :arg2, { key: "value" }], nil])
      end
    end

    context "when adding middleware class with block" do
      let(:middleware_class) { Class.new }
      let(:block) { proc { "config" } }

      it "stores block with middleware" do
        registry.use(middleware_class, &block)

        expect(registry.size).to eq(1)
        expect(registry.first).to eq([middleware_class, [], block])
      end
    end

    context "when adding middleware instance" do
      let(:middleware_instance) { double("MiddlewareInstance") }

      it "stores instance directly" do
        registry.use(middleware_instance)

        expect(registry.size).to eq(1)
        expect(registry.first).to eq([middleware_instance, [], nil])
      end
    end

    context "when adding proc middleware" do
      let(:middleware_proc) { proc { |task, callable| callable.call(task) } }

      it "stores proc as middleware" do
        registry.use(middleware_proc)

        expect(registry.size).to eq(1)
        expect(registry.first).to eq([middleware_proc, [], nil])
      end
    end

    context "when chaining multiple middleware additions" do
      let(:first_middleware) { Class.new }
      let(:second_middleware) { Class.new }
      let(:third_middleware) { Class.new }

      it "allows method chaining" do
        result = registry.use(first_middleware).use(second_middleware).use(third_middleware)

        expect(registry.size).to eq(3)
        expect(result).to eq(registry)
      end
    end
  end

  describe "#call" do
    context "when registry is empty" do
      it "executes block directly without middleware" do
        result = registry.call(task) { |_t| "direct_execution" }

        expect(result).to eq("direct_execution")
      end

      it "passes task to execution block" do
        executed_task = nil
        registry.call(task) { |t| executed_task = t }

        expect(executed_task).to eq(task)
      end
    end

    context "when registry has single middleware class" do
      let(:middleware_class) do
        Class.new do
          def call(task, callable)
            callable.call(task)
          end
        end
      end

      before do
        registry.use(middleware_class)
      end

      it "instantiates and calls middleware" do
        result = registry.call(task) { |_t| "executed" }

        expect(result).to eq("executed")
      end
    end

    context "when registry has single middleware instance" do
      let(:middleware_instance) { double("MiddlewareInstance") }

      before do
        registry.use(middleware_instance)
        allow(middleware_instance).to receive(:call) { |task, callable| callable.call(task) }
      end

      it "calls middleware instance directly" do
        result = registry.call(task) { |_t| "executed" }

        expect(middleware_instance).to have_received(:call)
        expect(result).to eq("executed")
      end
    end

    context "when registry has single proc middleware" do
      let(:middleware_proc) do
        proc { |task, callable| callable.call(task) }
      end

      before do
        registry.use(middleware_proc)
      end

      it "calls proc middleware directly" do
        result = registry.call(task) { |_t| "executed" }

        expect(result).to eq("executed")
      end
    end

    context "when registry has multiple middleware" do
      let(:execution_order) { [] }
      let(:outer_middleware) do
        Class.new do
          def initialize(order_tracker)
            @order_tracker = order_tracker
          end

          def call(task, callable)
            @order_tracker << "middleware1_before"
            result = callable.call(task)
            @order_tracker << "middleware1_after"
            result
          end
        end
      end

      let(:inner_middleware) do
        Class.new do
          def initialize(order_tracker)
            @order_tracker = order_tracker
          end

          def call(task, callable)
            @order_tracker << "middleware2_before"
            result = callable.call(task)
            @order_tracker << "middleware2_after"
            result
          end
        end
      end

      before do
        registry.use(outer_middleware, execution_order)
        registry.use(inner_middleware, execution_order)
      end

      it "executes middleware in correct order" do
        registry.call(task) do |_t|
          execution_order << "final_execution"
          "result"
        end

        expect(execution_order).to eq(%w[
                                        middleware1_before
                                        middleware2_before
                                        final_execution
                                        middleware2_after
                                        middleware1_after
                                      ])
      end
    end

    context "when middleware short-circuits execution" do
      let(:short_circuit_middleware) do
        Class.new do
          def call(task, callable)
            return "short_circuited" if task.should_stop?

            callable.call(task)
          end
        end
      end

      let(:second_middleware) do
        Class.new do
          def call(task, callable)
            callable.call(task)
          end
        end
      end

      before do
        registry.use(short_circuit_middleware)
        registry.use(second_middleware)
      end

      it "stops execution and returns early result" do
        allow(task).to receive(:should_stop?).and_return(true)

        result = registry.call(task) { |_t| "should_not_execute" }

        expect(result).to eq("short_circuited")
      end

      it "continues execution when condition is not met" do
        allow(task).to receive(:should_stop?).and_return(false)

        result = registry.call(task) { |_t| "final_result" }

        expect(result).to eq("final_result")
      end
    end

    context "when middleware modifies result" do
      let(:result_modifying_middleware) do
        Class.new do
          def call(task, callable)
            result = callable.call(task)
            "modified: #{result}"
          end
        end
      end

      before do
        registry.use(result_modifying_middleware)
      end

      it "returns modified result" do
        result = registry.call(task) { |_t| "original" }

        expect(result).to eq("modified: original")
      end
    end

    context "when middleware has initialization parameters" do
      let(:parameterized_middleware) do
        Class.new do
          def initialize(prefix)
            @prefix = prefix
          end

          def call(task, callable)
            result = callable.call(task)
            "#{@prefix}: #{result}"
          end
        end
      end

      before do
        registry.use(parameterized_middleware, "PREFIX")
      end

      it "passes initialization parameters to middleware" do
        result = registry.call(task) { |_t| "result" }

        expect(result).to eq("PREFIX: result")
      end
    end

    context "when middleware has initialization block" do
      let(:block_configured_middleware) do
        Class.new do
          def initialize(&block)
            @config = yield if block
          end

          def call(task, callable)
            result = callable.call(task)
            @config ? "#{@config}: #{result}" : result
          end
        end
      end

      before do
        registry.use(block_configured_middleware) { "BLOCK_CONFIG" }
      end

      it "passes initialization block to middleware" do
        result = registry.call(task) { |_t| "result" }

        expect(result).to eq("BLOCK_CONFIG: result")
      end
    end

    context "when mixing different middleware types" do
      let(:class_middleware) do
        Class.new do
          def call(task, callable)
            result = callable.call(task)
            "class: #{result}"
          end
        end
      end

      let(:instance_middleware) { double("InstanceMiddleware") }
      let(:proc_middleware) { proc { |task, callable| "proc: #{callable.call(task)}" } }

      before do
        registry.use(class_middleware)
        registry.use(instance_middleware)
        registry.use(proc_middleware)

        allow(instance_middleware).to receive(:call) do |task, callable|
          "instance: #{callable.call(task)}"
        end
      end

      it "executes all middleware types correctly" do
        result = registry.call(task) { |_t| "final" }

        expect(result).to eq("class: instance: proc: final")
      end
    end

    context "when middleware raises exceptions" do
      let(:failing_middleware) do
        Class.new do
          def call(_task, _callable)
            raise StandardError, "middleware failed"
          end
        end
      end

      before do
        registry.use(failing_middleware)
      end

      it "allows exceptions to propagate" do
        expect { registry.call(task) { |_t| "result" } }.to raise_error(StandardError, "middleware failed")
      end
    end

    context "when execution block raises exceptions" do
      let(:logging_middleware) do
        Class.new do
          def call(task, callable)
            callable.call(task)
          rescue StandardError => e
            "caught: #{e.message}"
          end
        end
      end

      before do
        registry.use(logging_middleware)
      end

      it "allows middleware to handle execution block exceptions" do
        result = registry.call(task) { |_t| raise StandardError, "execution failed" }

        expect(result).to eq("caught: execution failed")
      end
    end
  end
end

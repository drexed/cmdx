# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Correlate do
  include TaskBuilderHelpers

  subject(:middleware) { described_class.new }

  let(:task) { build_task.new }
  let(:result) { double("result") }
  let(:callable) { double("callable", call: result) }

  before { CMDx::Correlator.clear }

  describe "middleware inheritance" do
    it "inherits from CMDx::Middleware" do
      expect(described_class).to be < CMDx::Middleware
    end

    it "implements the required call method interface" do
      expect(middleware).to respond_to(:call)
    end
  end

  describe "initialization" do
    it "accepts an explicit correlation ID" do
      middleware = described_class.new(id: "explicit-123")
      expect(middleware.id).to eq("explicit-123")
    end

    it "accepts conditional options" do
      proc_condition = -> { false }
      middleware = described_class.new(if: :some_condition, unless: proc_condition)

      expect(middleware.conditional[:if]).to eq(:some_condition)
      expect(middleware.conditional[:unless]).to eq(proc_condition)
      expect(middleware.conditional.keys).to contain_exactly(:if, :unless)
    end

    it "initializes with empty options by default" do
      middleware = described_class.new
      expect(middleware.id).to be_nil
      expect(middleware.conditional).to eq({})
    end
  end

  describe "#call" do
    context "correlation ID precedence" do
      context "when explicit correlation ID is provided" do
        context "with string ID" do
          let(:explicit_id) { "explicit-correlation-123" }
          let(:middleware_with_id) { described_class.new(id: explicit_id) }

          before { CMDx::Correlator.id = "thread-correlation-456" }

          it "uses the explicit correlation ID over thread correlation" do
            expect(CMDx::Correlator).to receive(:use).with(explicit_id).and_call_original
            expect(callable).to receive(:call).with(task).and_return(result)

            middleware_with_id.call(task, callable)
          end

          it "uses the explicit correlation ID over chain ID" do
            task_with_run = build_task.new
            allow(task_with_run).to receive(:chain).and_return(CMDx::Chain.new(id: "chain-correlation-789"))

            expect(CMDx::Correlator).to receive(:use).with(explicit_id).and_call_original

            middleware_with_id.call(task_with_run, callable)
          end
        end

        context "with proc ID" do
          let(:middleware_with_proc) { described_class.new(id: proc_id) }
          let(:task_with_order) { build_task.new }

          before do
            allow(task_with_order).to receive(:order_id).and_return(456)
          end

          context "using simple proc" do
            let(:proc_id) { -> { "simple-proc-correlation" } }

            it "evaluates the proc to generate correlation ID" do
              expect(CMDx::Correlator).to receive(:use).with("simple-proc-correlation").and_call_original
              expect(callable).to receive(:call).with(task_with_order).and_return(result)

              middleware_with_proc.call(task_with_order, callable)
            end

            it "uses proc result over thread correlation" do
              CMDx::Correlator.id = "thread-correlation"

              expect(CMDx::Correlator).to receive(:use).with("simple-proc-correlation").and_call_original

              middleware_with_proc.call(task_with_order, callable)
            end
          end

          context "using proc with dynamic content" do
            let(:proc_id) { -> { "dynamic-proc-#{rand(1000)}" } }

            it "evaluates the proc to generate dynamic correlation ID" do
              expect(CMDx::Correlator).to receive(:use).with(String).and_call_original
              expect(callable).to receive(:call).with(task_with_order).and_return(result)

              middleware_with_proc.call(task_with_order, callable)
            end
          end
        end

        context "with method symbol ID" do
          let(:middleware_with_method) { described_class.new(id: :generate_correlation_id) }
          let(:task_with_method) { build_task.new }

          before do
            allow(task_with_method).to receive(:generate_correlation_id).and_return("method-generated-789")
          end

          it "calls the method on task to generate correlation ID" do
            expect(task_with_method).to receive(:generate_correlation_id).and_return("method-generated-789")
            expect(CMDx::Correlator).to receive(:use).with("method-generated-789").and_call_original
            expect(callable).to receive(:call).with(task_with_method).and_return(result)

            middleware_with_method.call(task_with_method, callable)
          end

          it "falls back to symbol value if method doesn't exist" do
            task_without_method = build_task.new
            expect(CMDx::Correlator).to receive(:use).with(:generate_correlation_id).and_call_original

            middleware_with_method.call(task_without_method, callable)
          end
        end
      end

      context "when thread correlation ID exists" do
        let(:thread_correlation) { "thread-correlation-123" }

        before { CMDx::Correlator.id = thread_correlation }

        it "uses the thread correlation ID" do
          expect(CMDx::Correlator).to receive(:use).with(thread_correlation).and_call_original
          expect(callable).to receive(:call).with(task).and_return(result)

          middleware.call(task, callable)
        end

        it "prefers thread correlation over chain ID" do
          # Create task with chain that has a different ID
          task_with_run = build_task.new
          allow(task_with_run).to receive(:chain).and_return(CMDx::Chain.new(id: "chain-correlation-456"))

          CMDx::Correlator.id = "thread-correlation-456"

          expect(CMDx::Correlator).to receive(:use).with("thread-correlation-456").and_call_original

          middleware.call(task_with_run, callable)
        end
      end

      context "when no thread correlation but chain ID exists" do
        let(:chain_with_id) { CMDx::Chain.new(id: "chain-correlation-789") }
        let(:task_with_run) { build_task.new }

        before do
          allow(task_with_run).to receive(:chain).and_return(chain_with_id)
        end

        it "uses the chain ID as correlation" do
          expect(CMDx::Correlator).to receive(:use).with("chain-correlation-789").and_call_original

          middleware.call(task_with_run, callable)
        end
      end

      context "when no thread correlation or chain ID exists" do
        let(:generated_id) { "generated-uuid-123" }

        before do
          allow(CMDx::Correlator).to receive(:generate).and_return(generated_id)
        end

        it "generates a new correlation ID" do
          expect(CMDx::Correlator).to receive(:generate).and_return(generated_id)
          expect(CMDx::Correlator).to receive(:use).with(generated_id).and_call_original

          middleware.call(task, callable)
        end
      end
    end

    context "correlation context management" do
      it "establishes correlation context during task execution" do
        correlation_inside = nil
        expect(callable).to receive(:call) do |task|
          correlation_inside = CMDx::Correlator.id
          result
        end

        middleware.call(task, callable)

        expect(correlation_inside).not_to be_nil
        expect(correlation_inside).not_to be_empty
      end

      it "restores previous correlation context after execution" do
        original_correlation = "original-correlation"
        CMDx::Correlator.id = original_correlation

        # Create task with different chain ID
        task_with_run = build_task.new
        allow(task_with_run).to receive(:chain).and_return(CMDx::Chain.new(id: "task-specific-correlation"))

        middleware.call(task_with_run, callable)

        expect(CMDx::Correlator.id).to eq(original_correlation)
      end

      it "clears correlation when no previous context existed" do
        # Ensure no correlation exists
        CMDx::Correlator.clear

        middleware.call(task, callable)

        expect(CMDx::Correlator.id).to be_nil
      end
    end

    context "exception handling" do
      let(:test_error) { StandardError.new("test error") }

      it "restores correlation context even when task raises exception" do
        original_correlation = "original-correlation"
        CMDx::Correlator.id = original_correlation

        # Create task with different chain ID
        task_with_run = build_task.new
        allow(task_with_run).to receive(:chain).and_return(CMDx::Chain.new(id: "task-specific-correlation"))

        expect(callable).to receive(:call).and_raise(test_error)

        expect do
          middleware.call(task_with_run, callable)
        end.to raise_error(test_error)

        expect(CMDx::Correlator.id).to eq(original_correlation)
      end

      it "clears correlation context when no original existed and task raises exception" do
        CMDx::Correlator.clear

        expect(callable).to receive(:call).and_raise(test_error)

        expect do
          middleware.call(task, callable)
        end.to raise_error(test_error)

        expect(CMDx::Correlator.id).to be_nil
      end
    end

    context "integration with task execution" do
      it "provides correlation ID during task execution" do
        captured_correlation = nil
        expect(callable).to receive(:call) do |task|
          captured_correlation = CMDx::Correlator.id
          result
        end

        middleware.call(task, callable)

        expect(captured_correlation).not_to be_nil
        expect(captured_correlation).not_to be_empty
        expect(captured_correlation).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/) # UUID format
      end

      it "maintains correlation across nested task calls" do
        correlation_stack = []
        nested_callable = double("nested_callable")

        expect(callable).to receive(:call) do |task|
          correlation_stack << CMDx::Correlator.id

          # Simulate nested task call with middleware
          nested_task = build_task.new
          middleware.call(nested_task, nested_callable)

          result
        end

        expect(nested_callable).to receive(:call) do |nested_task|
          correlation_stack << CMDx::Correlator.id
          double("nested_result")
        end

        middleware.call(task, callable)

        expect(correlation_stack.size).to eq(2)
        expect(correlation_stack[0]).to eq(correlation_stack[1]) # Same correlation across nested calls
      end

      it "uses chain ID as correlation when no thread correlation exists" do
        CMDx::Correlator.clear

        # Create task with specific chain ID
        task_with_run = build_task.new
        chain_with_id = CMDx::Chain.new(id: "specific-chain-id")
        allow(task_with_run).to receive(:chain).and_return(chain_with_id)

        captured_correlation = nil
        expect(callable).to receive(:call) do |task|
          captured_correlation = CMDx::Correlator.id
          result
        end

        middleware.call(task_with_run, callable)

        expect(captured_correlation).to eq("specific-chain-id")
      end
    end

    context "conditional execution" do
      let(:test_task) { build_task.new }

      context "with :if condition" do
        it "executes correlation when :if condition is true" do
          middleware = described_class.new(if: -> { true })

          expect(CMDx::Correlator).to receive(:use).and_call_original
          expect(callable).to receive(:call).with(test_task).and_return(result)

          middleware.call(test_task, callable)
        end

        it "skips correlation when :if condition is false" do
          middleware = described_class.new(if: -> { false })

          expect(CMDx::Correlator).not_to receive(:use)
          expect(callable).to receive(:call).with(test_task).and_return(result)

          middleware.call(test_task, callable)
        end

        it "works with symbol conditions" do
          middleware = described_class.new(if: :correlation_enabled?)

          allow(test_task).to receive(:correlation_enabled?).and_return(true)
          expect(CMDx::Correlator).to receive(:use).and_call_original

          middleware.call(test_task, callable)
        end
      end

      context "with :unless condition" do
        it "executes correlation when :unless condition is false" do
          middleware = described_class.new(unless: -> { false })

          expect(CMDx::Correlator).to receive(:use).and_call_original
          expect(callable).to receive(:call).with(test_task).and_return(result)

          middleware.call(test_task, callable)
        end

        it "skips correlation when :unless condition is true" do
          middleware = described_class.new(unless: -> { true })

          expect(CMDx::Correlator).not_to receive(:use)
          expect(callable).to receive(:call).with(test_task).and_return(result)

          middleware.call(test_task, callable)
        end

        it "works with symbol conditions" do
          middleware = described_class.new(unless: :correlation_disabled?)

          allow(test_task).to receive(:correlation_disabled?).and_return(false)
          expect(CMDx::Correlator).to receive(:use).and_call_original

          middleware.call(test_task, callable)
        end
      end

      context "with both :if and :unless conditions" do
        it "executes when both conditions are satisfied" do
          middleware = described_class.new(if: -> { true }, unless: -> { false })

          expect(CMDx::Correlator).to receive(:use).and_call_original
          expect(callable).to receive(:call).with(test_task).and_return(result)

          middleware.call(test_task, callable)
        end

        it "skips when :if condition is false" do
          middleware = described_class.new(if: -> { false }, unless: -> { false })

          expect(CMDx::Correlator).not_to receive(:use)
          expect(callable).to receive(:call).with(test_task).and_return(result)

          middleware.call(test_task, callable)
        end

        it "skips when :unless condition is true" do
          middleware = described_class.new(if: -> { true }, unless: -> { true })

          expect(CMDx::Correlator).not_to receive(:use)
          expect(callable).to receive(:call).with(test_task).and_return(result)

          middleware.call(test_task, callable)
        end
      end
    end

    context "thread safety" do
      it "maintains separate correlation contexts per thread" do
        correlations = {}
        threads = []

        3.times do |i|
          threads << Thread.new do
            # Set unique correlation for each thread
            thread_correlation = "thread-#{i}-correlation"
            CMDx::Correlator.id = thread_correlation

            task_for_thread = build_task.new
            callable_for_thread = double("callable_#{i}")

            expect(callable_for_thread).to receive(:call) do |task|
              correlations[Thread.current] = CMDx::Correlator.id
              double("result_#{i}")
            end

            middleware.call(task_for_thread, callable_for_thread)
          end
        end

        threads.each(&:join)

        expect(correlations.values).to contain_exactly(
          "thread-0-correlation",
          "thread-1-correlation",
          "thread-2-correlation"
        )
      end
    end
  end

  describe "correlation ID determination" do
    context "precedence scenarios" do
      it "follows the correct precedence hierarchy" do
        # Test all precedence scenarios in one comprehensive test
        results = {}

        # Scenario 1: Explicit string ID takes precedence over everything
        middleware_with_id = described_class.new(id: "explicit-correlation")
        CMDx::Correlator.id = "thread-correlation"
        task_with_run = build_task.new
        allow(task_with_run).to receive(:chain).and_return(CMDx::Chain.new(id: "chain-correlation"))

        expect(CMDx::Correlator).to receive(:use).with("explicit-correlation").and_call_original
        middleware_with_id.call(task_with_run, callable)
        results[:explicit_over_all] = true

        # Scenario 2: Explicit proc ID takes precedence over everything
        middleware_with_proc = described_class.new(id: -> { "proc-generated-#{Time.now.to_i.to_s[-3..-1]}" })
        expect(CMDx::Correlator).to receive(:use).with(String).and_call_original
        middleware_with_proc.call(task_with_run, callable)
        results[:proc_over_all] = true

        # Scenario 3: Method-based ID takes precedence over thread/chain
        middleware_with_method = described_class.new(id: :test_correlation_method)
        allow(task_with_run).to receive(:test_correlation_method).and_return("method-generated")
        expect(CMDx::Correlator).to receive(:use).with("method-generated").and_call_original
        middleware_with_method.call(task_with_run, callable)
        results[:method_over_all] = true

        # Scenario 4: Thread correlation takes precedence over chain ID
        expect(CMDx::Correlator).to receive(:use).with("thread-correlation").and_call_original
        middleware.call(task_with_run, callable)
        results[:thread_over_chain] = true

        # Scenario 5: Chain ID used when no thread correlation
        CMDx::Correlator.clear
        expect(CMDx::Correlator).to receive(:use).with("chain-correlation").and_call_original
        middleware.call(task_with_run, callable)
        results[:chain_when_no_thread] = true

        # Scenario 6: Generated ID when no explicit, thread, or chain correlation
        task_without_chain_id = build_task.new
        mock_chain = double("chain", id: nil)
        allow(task_without_chain_id).to receive(:chain).and_return(mock_chain)

        expect(CMDx::Correlator).to receive(:generate).and_return("generated-id")
        expect(CMDx::Correlator).to receive(:use).with("generated-id").and_call_original
        middleware.call(task_without_chain_id, callable)
        results[:generated_when_none] = true

        expect(results).to eq({
                                explicit_over_all: true,
                                proc_over_all: true,
                                method_over_all: true,
                                thread_over_chain: true,
                                chain_when_no_thread: true,
                                generated_when_none: true
                              })
      end
    end

    context "__cmdx_yield integration" do
      it "handles different types of ID values correctly" do
        test_task = build_task.new
        allow(test_task).to receive(:custom_method).and_return("custom-result")

        # String ID - returned as-is
        middleware_string = described_class.new(id: "static-string")
        expect(CMDx::Correlator).to receive(:use).with("static-string").and_call_original
        middleware_string.call(test_task, callable)

        # Symbol ID that matches a method - method is called
        middleware_method = described_class.new(id: :custom_method)
        expect(CMDx::Correlator).to receive(:use).with("custom-result").and_call_original
        middleware_method.call(test_task, callable)

        # Symbol ID that doesn't match a method - symbol returned as-is
        middleware_symbol = described_class.new(id: :nonexistent_method)
        expect(CMDx::Correlator).to receive(:use).with(:nonexistent_method).and_call_original
        middleware_symbol.call(test_task, callable)

        # Proc ID - executed in task context
        middleware_proc = described_class.new(id: -> { "proc-#{object_id}" })
        expect(CMDx::Correlator).to receive(:use).with(String).and_call_original
        middleware_proc.call(test_task, callable)
      end
    end
  end
end

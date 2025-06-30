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

  describe "#call" do
    context "correlation ID precedence" do
      context "when thread correlation ID exists" do
        let(:thread_correlation) { "thread-correlation-123" }

        before { CMDx::Correlator.id = thread_correlation }

        it "uses the thread correlation ID" do
          expect(CMDx::Correlator).to receive(:use).with(thread_correlation).and_call_original
          expect(callable).to receive(:call).with(task).and_return(result)

          middleware.call(task, callable)
        end

        it "prefers thread correlation over run ID" do
          # Create task with run that has a different ID
          task_with_run = build_task.new
          allow(task_with_run).to receive(:run).and_return(CMDx::Run.new(id: "run-correlation-456"))

          CMDx::Correlator.id = "thread-correlation-456"

          expect(CMDx::Correlator).to receive(:use).with("thread-correlation-456").and_call_original

          middleware.call(task_with_run, callable)
        end
      end

      context "when no thread correlation but run ID exists" do
        let(:run_with_id) { CMDx::Run.new(id: "run-correlation-789") }
        let(:task_with_run) { build_task.new }

        before do
          allow(task_with_run).to receive(:run).and_return(run_with_id)
        end

        it "uses the run ID as correlation" do
          expect(CMDx::Correlator).to receive(:use).with("run-correlation-789").and_call_original

          middleware.call(task_with_run, callable)
        end
      end

      context "when no thread correlation or run ID exists" do
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

        # Create task with different run ID
        task_with_run = build_task.new
        allow(task_with_run).to receive(:run).and_return(CMDx::Run.new(id: "task-specific-correlation"))

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

        # Create task with different run ID
        task_with_run = build_task.new
        allow(task_with_run).to receive(:run).and_return(CMDx::Run.new(id: "task-specific-correlation"))

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

      it "uses run ID as correlation when no thread correlation exists" do
        CMDx::Correlator.clear

        # Create task with specific run ID
        task_with_run = build_task.new
        run_with_id = CMDx::Run.new(id: "specific-run-id")
        allow(task_with_run).to receive(:run).and_return(run_with_id)

        captured_correlation = nil
        expect(callable).to receive(:call) do |task|
          captured_correlation = CMDx::Correlator.id
          result
        end

        middleware.call(task_with_run, callable)

        expect(captured_correlation).to eq("specific-run-id")
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

        # Scenario 1: Thread correlation takes precedence over run ID
        CMDx::Correlator.id = "thread-correlation"
        task_with_run = build_task.new
        allow(task_with_run).to receive(:run).and_return(CMDx::Run.new(id: "run-correlation"))

        expect(CMDx::Correlator).to receive(:use).with("thread-correlation").and_call_original
        middleware.call(task_with_run, callable)
        results[:thread_over_run] = true

        # Scenario 2: Run ID used when no thread correlation
        CMDx::Correlator.clear
        expect(CMDx::Correlator).to receive(:use).with("run-correlation").and_call_original
        middleware.call(task_with_run, callable)
        results[:run_when_no_thread] = true

        # Scenario 3: Generated ID when neither thread nor run correlation
        task_without_run_id = build_task.new
        mock_run = double("run", id: nil)
        allow(task_without_run_id).to receive(:run).and_return(mock_run)

        expect(CMDx::Correlator).to receive(:generate).and_return("generated-id")
        expect(CMDx::Correlator).to receive(:use).with("generated-id").and_call_original
        middleware.call(task_without_run_id, callable)
        results[:generated_when_none] = true

        expect(results).to eq({
                                thread_over_run: true,
                                run_when_no_thread: true,
                                generated_when_none: true
                              })
      end
    end
  end
end

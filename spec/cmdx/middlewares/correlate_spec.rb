# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Correlate do
  subject(:middleware) { described_class.new(options) }

  let(:options) { {} }
  let(:task) { task_class.new }
  let(:task_class) { create_simple_task }
  let(:callable) { ->(_task) { "result" } }

  describe "#initialize" do
    context "with default options" do
      it "sets id to nil" do
        expect(middleware.id).to be_nil
      end

      it "sets empty conditional options" do
        expect(middleware.conditional).to eq({})
      end
    end

    context "with custom id" do
      let(:options) { { id: "custom-correlation-id" } }

      it "sets the custom id" do
        expect(middleware.id).to eq("custom-correlation-id")
      end
    end

    context "with proc id" do
      let(:id_proc) { -> { "dynamic-id" } }
      let(:options) { { id: id_proc } }

      it "stores proc as id value" do
        expect(middleware.id).to eq(id_proc)
      end
    end

    context "with conditional options" do
      let(:options) { { id: "test-id", if: :should_correlate?, unless: :skip_correlation? } }

      it "extracts conditional options" do
        expect(middleware.conditional).to eq(if: :should_correlate?, unless: :skip_correlation?)
      end
    end
  end

  describe "#call" do
    before do
      allow(CMDx::Correlator).to receive_messages(id: nil, generate: "generated-id")
      allow(CMDx::Correlator).to receive(:use).and_yield
    end

    context "when task execution completes successfully" do
      it "returns the result of the callable" do
        result = middleware.call(task, callable)
        expect(result).to eq("result")
      end

      it "wraps execution in correlation context" do
        expect(CMDx::Correlator).to receive(:use).with("generated-id").and_yield

        middleware.call(task, callable)
      end
    end

    context "with explicit correlation id" do
      let(:options) { { id: "explicit-id" } }

      it "uses the explicit id for correlation" do
        expect(CMDx::Correlator).to receive(:use).with("explicit-id").and_yield

        middleware.call(task, callable)
      end
    end

    context "with proc correlation id" do
      let(:options) { { id: -> { "proc-generated-id" } } }

      it "evaluates proc to get correlation id" do
        expect(CMDx::Correlator).to receive(:use).with("proc-generated-id").and_yield

        middleware.call(task, callable)
      end
    end

    context "with symbol correlation id" do
      let(:task_class) do
        create_simple_task do
          def correlation_id
            "method-generated-id"
          end
        end
      end
      let(:options) { { id: :correlation_id } }

      it "calls method to get correlation id" do
        expect(CMDx::Correlator).to receive(:use).with("method-generated-id").and_yield

        middleware.call(task, callable)
      end
    end

    context "with fallback correlation id sources" do
      context "when correlator has existing id" do
        before do
          allow(CMDx::Correlator).to receive(:id).and_return("existing-correlator-id")
        end

        it "uses existing correlator id" do
          expect(CMDx::Correlator).to receive(:use).with("existing-correlator-id").and_yield

          middleware.call(task, callable)
        end
      end

      context "when chain has id" do
        before do
          allow(task).to receive(:chain).and_return(double(id: "chain-id"))
        end

        it "uses chain id when correlator id is nil" do
          expect(CMDx::Correlator).to receive(:use).with("chain-id").and_yield

          middleware.call(task, callable)
        end
      end

      context "when no id sources available" do
        it "generates new correlation id" do
          allow(CMDx::Correlator).to receive(:generate).and_return("new-generated-id")
          expect(CMDx::Correlator).to receive(:use).with("new-generated-id").and_yield

          middleware.call(task, callable)
        end
      end
    end

    context "with conditional execution" do
      let(:task_class) do
        create_simple_task do
          def should_correlate?
            @should_correlate || false # rubocop:disable RSpec/InstanceVariable
          end

          attr_writer :should_correlate

          def skip_correlation?
            @skip_correlation || false # rubocop:disable RSpec/InstanceVariable
          end

          attr_writer :skip_correlation
        end
      end

      context "with :if condition" do
        let(:options) { { id: "conditional-id", if: :should_correlate? } }

        it "applies correlation when condition is truthy" do
          task.should_correlate = true
          expect(CMDx::Correlator).to receive(:use).with("conditional-id").and_yield

          middleware.call(task, callable)
        end

        it "skips correlation when condition is falsy" do
          task.should_correlate = false
          expect(CMDx::Correlator).not_to receive(:use)

          result = middleware.call(task, callable)
          expect(result).to eq("result")
        end
      end

      context "with :unless condition" do
        let(:options) { { id: "conditional-id", unless: :skip_correlation? } }

        it "applies correlation when condition is falsy" do
          task.skip_correlation = false
          expect(CMDx::Correlator).to receive(:use).with("conditional-id").and_yield

          middleware.call(task, callable)
        end

        it "skips correlation when condition is truthy" do
          task.skip_correlation = true
          expect(CMDx::Correlator).not_to receive(:use)

          result = middleware.call(task, callable)
          expect(result).to eq("result")
        end
      end

      context "with both :if and :unless conditions" do
        let(:options) { { id: "conditional-id", if: :should_correlate?, unless: :skip_correlation? } }

        it "applies correlation when :if is truthy and :unless is falsy" do
          task.should_correlate = true
          task.skip_correlation = false
          expect(CMDx::Correlator).to receive(:use).with("conditional-id").and_yield

          middleware.call(task, callable)
        end

        it "skips correlation when :unless is truthy regardless of :if" do
          task.should_correlate = true
          task.skip_correlation = true
          expect(CMDx::Correlator).not_to receive(:use)

          result = middleware.call(task, callable)
          expect(result).to eq("result")
        end
      end
    end

    context "when callable raises exception" do
      let(:error_callable) { ->(_task) { raise StandardError, "Something went wrong" } }

      it "allows exception to propagate while maintaining correlation context" do
        expect(CMDx::Correlator).to receive(:use).and_yield
        expect { middleware.call(task, error_callable) }.to raise_error(StandardError, "Something went wrong")
      end
    end
  end

  describe "integration with tasks" do
    let(:basic_task_class) do
      create_simple_task(name: "BasicCorrelatedTask") do
        use :middleware, CMDx::Middlewares::Correlate, id: "task-correlation-id" # rubocop:disable RSpec/DescribedClass

        def call
          context.correlation_used = true
          context.result = "correlated execution"
        end
      end
    end

    let(:dynamic_task_class) do
      create_simple_task(name: "DynamicCorrelatedTask") do
        use :middleware, CMDx::Middlewares::Correlate, id: :generate_correlation_id # rubocop:disable RSpec/DescribedClass

        def call
          context.correlation_used = true
          context.result = "dynamic correlation"
        end

        private

        def generate_correlation_id
          "dynamic-#{Time.now.to_i}"
        end
      end
    end

    let(:conditional_task_class) do
      create_simple_task(name: "ConditionalCorrelatedTask") do
        use :middleware, CMDx::Middlewares::Correlate, id: "conditional-id", if: :should_trace? # rubocop:disable RSpec/DescribedClass

        optional :enable_tracing, type: :boolean, default: false

        def call
          context.correlation_used = true
          context.result = "conditional correlation"
        end

        private

        def should_trace?
          enable_tracing
        end
      end
    end

    before do
      allow(CMDx::Correlator).to receive(:use).and_yield
    end

    it "applies correlation to task execution" do
      expect(CMDx::Correlator).to receive(:use).with("task-correlation-id").and_yield

      result = basic_task_class.call
      expect(result).to be_success
      expect(result.context.correlation_used).to be(true)
      expect(result.context.result).to eq("correlated execution")
    end

    it "uses dynamic correlation id generation" do
      expect(CMDx::Correlator).to receive(:use).with(start_with("dynamic-")).and_yield

      result = dynamic_task_class.call
      expect(result).to be_success
      expect(result.context.result).to eq("dynamic correlation")
    end

    it "applies correlation conditionally" do
      # Without tracing enabled
      result_without_tracing = conditional_task_class.call(enable_tracing: false)
      expect(result_without_tracing).to be_success

      # With tracing enabled
      expect(CMDx::Correlator).to receive(:use).with("conditional-id").and_yield
      result_with_tracing = conditional_task_class.call(enable_tracing: true)
      expect(result_with_tracing).to be_success
    end

    it "verifies middleware is properly registered on task class" do
      expect(basic_task_class.cmd_middlewares.registry).to have_key(described_class)
      expect(dynamic_task_class.cmd_middlewares.registry).to have_key(described_class)
      expect(conditional_task_class.cmd_middlewares.registry).to have_key(described_class)
    end

    it "maintains correlation context when task fails" do
      failing_task_class = create_simple_task(name: "FailingCorrelatedTask") do
        use :middleware, CMDx::Middlewares::Correlate, id: "failing-task-id" # rubocop:disable RSpec/DescribedClass

        def call
          context.started = true
          fault!("Task failed intentionally")
        end
      end

      expect(CMDx::Correlator).to receive(:use).with("failing-task-id").and_yield

      result = failing_task_class.call
      expect(result).to be_failed
      expect(result.context.started).to be(true)
    end
  end
end

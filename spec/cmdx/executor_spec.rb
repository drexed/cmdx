# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Executor, type: :unit do
  subject(:worker) { described_class.new(task) }

  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:task) { task_class.new }

  describe "#initialize" do
    it "assigns the task" do
      expect(worker.task).to eq(task)
    end

    it "provides read access to task attribute" do
      expect(described_class.instance_methods).to include(:task)
      expect(described_class.private_instance_methods).not_to include(:task)
    end
  end

  describe ".execute" do
    context "with raise: false" do
      it "creates worker instance and calls execute" do
        expect(described_class).to receive(:new).with(task).and_return(worker)
        expect(worker).to receive(:execute).and_return(:result)

        result = described_class.execute(task, raise: false)

        expect(result).to eq(:result)
      end
    end

    context "with raise: true" do
      it "creates worker instance and calls execute!" do
        expect(described_class).to receive(:new).with(task).and_return(worker)
        expect(worker).to receive(:execute!).and_return(:result)

        result = described_class.execute(task, raise: true)

        expect(result).to eq(:result)
      end
    end

    context "without raise parameter" do
      it "defaults to raise: false" do
        expect(described_class).to receive(:new).with(task).and_return(worker)
        expect(worker).to receive(:execute).and_return(:result)

        described_class.execute(task)
      end
    end
  end

  describe "#execute" do
    let(:middlewares) { instance_double(CMDx::MiddlewareRegistry) }
    let(:logger) { instance_double(Logger) }
    let(:callbacks) { instance_double(CMDx::CallbackRegistry) }

    before do
      allow(callbacks).to receive(:invoke)
      allow(task.class).to receive(:settings).and_return({ middlewares: middlewares, callbacks: callbacks })
      allow(task).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(worker).to receive(:freeze_execution!)

      # Setup result state to support proper transitions
      allow(task.result).to receive_messages(to_h: { test: "data" }, state: "executing", executing?: true, executed?: true, success?: true)
      allow(task.result).to receive(:complete!)
      allow(task.result).to receive(:executed!)
    end

    context "when execution is successful" do
      it "calls middleware with task and executes successfully" do
        expect(middlewares).to receive(:call!).with(task).and_yield
        expect(worker).to receive(:pre_execution!)
        expect(worker).to receive(:execution!)
        expect(task.result).to receive(:executed!)
        expect(worker).to receive(:post_execution!)
        expect(worker).to receive(:freeze_execution!)

        worker.execute
      end

      it "logs execution information" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!)
        allow(task.result).to receive(:executed!)
        allow(worker).to receive(:post_execution!)

        expect(logger).to receive(:info)

        worker.execute
      end
    end

    context "when UndefinedMethodError is raised" do
      let(:undefined_error) { CMDx::UndefinedMethodError.new("undefined method") }

      it "re-raises the exception without clearing chain" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(undefined_error)

        expect(CMDx::Chain).to receive(:clear).at_least(:once)

        expect { worker.execute }.to raise_error(CMDx::UndefinedMethodError)
      end
    end

    context "when Fault is raised" do
      let(:fault_result) { instance_double(CMDx::Result, reason: "test failure") }
      let(:fault) { CMDx::FailFault.new(fault_result) }

      it "calls throw! on task result with fault result" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(fault)

        expect(task.result).to receive(:throw!).with(fault_result, halt: false, cause: fault)

        allow(task.result).to receive(:executed!)
        allow(worker).to receive(:post_execution!)

        worker.execute
      end

      it "continues with normal execution flow" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(fault)
        allow(task.result).to receive(:throw!)

        expect(task.result).to receive(:executed!)
        expect(worker).to receive(:post_execution!)
        expect(worker).to receive(:freeze_execution!)

        worker.execute
      end
    end

    context "when StandardError is raised" do
      let(:standard_error) { StandardError.new("something went wrong") }

      it "calls fail! on task result with formatted error message" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(standard_error)

        expect(task.result).to receive(:fail!).with("[StandardError] something went wrong", halt: false, cause: standard_error)

        allow(task.result).to receive(:executed!)
        allow(worker).to receive(:post_execution!)

        worker.execute
      end

      it "continues with normal execution flow" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(standard_error)
        allow(task.result).to receive(:fail!)

        expect(task.result).to receive(:executed!)
        expect(worker).to receive(:post_execution!)
        expect(worker).to receive(:freeze_execution!)

        worker.execute
      end
    end

    context "when custom error is raised" do
      let(:custom_error) { CMDx::TestError.new("test error") }

      it "calls fail! on task result with formatted error message" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(custom_error)

        expect(task.result).to receive(:fail!).with("[CMDx::TestError] test error", halt: false, cause: custom_error)

        allow(task.result).to receive(:executed!)
        allow(worker).to receive(:post_execution!)

        worker.execute
      end
    end
  end

  describe "#execute!" do
    let(:middlewares) { instance_double(CMDx::MiddlewareRegistry) }
    let(:logger) { instance_double(Logger) }
    let(:callbacks) { instance_double(CMDx::CallbackRegistry) }

    before do
      allow(callbacks).to receive(:invoke)
      allow(task.class).to receive(:settings).and_return({ middlewares: middlewares, callbacks: callbacks })
      allow(task).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(worker).to receive(:freeze_execution!)

      # Setup result state to support proper transitions
      allow(task.result).to receive_messages(to_h: { test: "data" }, state: "executing", executing?: true, executed?: true, success?: true)
      allow(task.result).to receive(:complete!)
      allow(task.result).to receive(:executed!)
    end

    context "when execution is successful" do
      it "calls middleware with task and executes successfully" do
        expect(middlewares).to receive(:call!).with(task).and_yield
        expect(worker).to receive(:pre_execution!)
        expect(worker).to receive(:execution!)
        expect(task.result).to receive(:executed!)
        expect(worker).to receive(:post_execution!)
        expect(worker).to receive(:freeze_execution!)

        worker.execute!
      end
    end

    context "when UndefinedMethodError is raised" do
      let(:undefined_error) { CMDx::UndefinedMethodError.new("undefined method") }

      it "calls raise_exception with the error" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(undefined_error)

        expect(worker).to receive(:raise_exception).with(undefined_error).and_raise(undefined_error)

        expect { worker.execute! }.to raise_error(undefined_error)
      end
    end

    context "when Fault is raised" do
      let(:fault_result) { instance_double(CMDx::Result, status: "failed", reason: "test failure") }
      let(:fault) { CMDx::FailFault.new(fault_result) }

      context "when halt_execution? returns false" do
        it "calls throw! and post_execution!" do
          expect(middlewares).to receive(:call!).with(task).and_yield

          allow(worker).to receive(:pre_execution!)
          allow(worker).to receive(:execution!).and_raise(fault)

          expect(task.result).to receive(:throw!).with(fault_result, halt: false, cause: fault)
          expect(worker).to receive(:halt_execution?).with(fault).and_return(false)
          expect(worker).to receive(:post_execution!)

          worker.execute!
        end
      end

      context "when halt_execution? returns true" do
        it "calls throw! and raise_exception" do
          expect(middlewares).to receive(:call!).with(task).and_yield

          allow(worker).to receive(:pre_execution!)
          allow(worker).to receive(:execution!).and_raise(fault)

          expect(task.result).to receive(:throw!).with(fault_result, halt: false, cause: fault)
          expect(worker).to receive(:halt_execution?).with(fault).and_return(true)
          expect(worker).to receive(:raise_exception).with(fault).and_raise(fault)

          expect { worker.execute! }.to raise_error(fault)
        end
      end
    end

    context "when StandardError is raised" do
      let(:standard_error) { StandardError.new("something went wrong") }

      it "calls fail! and raise_exception" do
        expect(middlewares).to receive(:call!).with(task).and_yield

        allow(worker).to receive(:pre_execution!)
        allow(worker).to receive(:execution!).and_raise(standard_error)

        expect(task.result).to receive(:fail!).with("[StandardError] something went wrong", halt: false, cause: standard_error)
        expect(worker).to receive(:raise_exception).with(standard_error).and_raise(standard_error)

        expect { worker.execute! }.to raise_error(standard_error)
      end
    end
  end

  describe "#halt_execution?" do
    let(:fault_result) { instance_double(CMDx::Result, status: "failed", reason: "test failure") }
    let(:fault) { CMDx::FailFault.new(fault_result) }

    context "when breakpoints setting exists" do
      before do
        allow(task.class).to receive(:settings).and_return({ breakpoints: %w[failed skipped] })
      end

      context "when exception result status is in breakpoints" do
        it "returns true" do
          expect(worker.send(:halt_execution?, fault)).to be(true)
        end
      end

      context "when exception result status is not in breakpoints" do
        let(:success_result) { instance_double(CMDx::Result, status: "success", reason: "test success") }
        let(:success_fault) { CMDx::SkipFault.new(success_result) }

        it "returns false" do
          expect(worker.send(:halt_execution?, success_fault)).to be(false)
        end
      end
    end

    context "when task_breakpoints setting exists" do
      before do
        allow(task.class).to receive(:settings).and_return({ task_breakpoints: [:failed] })
      end

      it "converts symbols to strings and checks inclusion" do
        expect(worker.send(:halt_execution?, fault)).to be(true)
      end
    end

    context "when no breakpoints are configured" do
      before do
        allow(task.class).to receive(:settings).and_return({})
      end

      it "returns false" do
        expect(worker.send(:halt_execution?, fault)).to be(false)
      end
    end

    context "when breakpoints is nil" do
      before do
        allow(task.class).to receive(:settings).and_return({ breakpoints: nil })
      end

      it "returns false" do
        expect(worker.send(:halt_execution?, fault)).to be(false)
      end
    end

    context "with duplicate breakpoints" do
      before do
        allow(task.class).to receive(:settings).and_return({ breakpoints: ["failed", "failed", :failed] })
      end

      it "removes duplicates after string conversion" do
        expect(worker.send(:halt_execution?, fault)).to be(true)
      end
    end
  end

  describe "#retry_execution?" do
    let(:exception) { StandardError.new("test error") }
    let(:logger) { instance_double(Logger) }

    before do
      allow(logger).to receive(:warn)
      allow(task).to receive_messages(logger: logger, to_h: { id: "123" })
    end

    context "when retries is not configured" do
      before do
        allow(task.class).to receive(:settings).and_return({})
      end

      it "returns false" do
        expect(worker.send(:retry_execution?, exception)).to be(false)
      end
    end

    context "when retries is 0" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 0 })
      end

      it "returns false" do
        expect(worker.send(:retry_execution?, exception)).to be(false)
      end
    end

    context "when retries are exhausted" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 2 })
        allow(task.result).to receive(:metadata).and_return({ retries: 2 })
      end

      it "returns false" do
        expect(worker.send(:retry_execution?, exception)).to be(false)
      end
    end

    context "when exception type does not match retry_on" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3, retry_on: [ArgumentError] })
        allow(task.result).to receive(:metadata).and_return({ retries: 0 })
      end

      it "returns false" do
        expect(worker.send(:retry_execution?, exception)).to be(false)
      end
    end

    context "when retry should happen" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3 })
        allow(task.result).to receive(:metadata).and_return({ retries: 0 })
      end

      it "returns true" do
        expect(worker.send(:retry_execution?, exception)).to be(true)
      end

      it "increments retry count in metadata" do
        metadata = { retries: 1 }
        allow(task.result).to receive(:metadata).and_return(metadata)

        worker.send(:retry_execution?, exception)

        expect(metadata[:retries]).to eq(2)
      end

      it "logs warning with reason and remaining retries" do
        expect(logger).to receive(:warn) do |&block|
          result = block.call
          expect(result[:reason]).to eq("[StandardError] test error")
          expect(result[:remaining_retries]).to eq(3)
        end

        worker.send(:retry_execution?, exception)
      end
    end

    context "with retry_on configuration" do
      context "when exception matches configured type" do
        before do
          allow(task.class).to receive(:settings).and_return({ retries: 2, retry_on: [StandardError] })
          allow(task.result).to receive(:metadata).and_return({ retries: 0 })
        end

        it "returns true" do
          expect(worker.send(:retry_execution?, exception)).to be(true)
        end
      end

      context "when exception is subclass of configured type" do
        let(:custom_error) { CMDx::TestError.new("test error") }

        before do
          allow(task.class).to receive(:settings).and_return({ retries: 2, retry_on: [StandardError] })
          allow(task.result).to receive(:metadata).and_return({ retries: 0 })
        end

        it "returns true" do
          expect(worker.send(:retry_execution?, custom_error)).to be(true)
        end
      end

      context "when multiple exception types are configured" do
        before do
          allow(task.class).to receive(:settings).and_return({ retries: 2, retry_on: [ArgumentError, StandardError] })
          allow(task.result).to receive(:metadata).and_return({ retries: 0 })
        end

        it "returns true if exception matches any type" do
          expect(worker.send(:retry_execution?, exception)).to be(true)
        end
      end
    end

    context "with retry_jitter as numeric value" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3, retry_jitter: 0.5 })
        allow(task.result).to receive(:metadata).and_return({ retries: 1 })
      end

      it "sleeps for jitter multiplied by current retries" do
        expect(worker).to receive(:sleep).with(0.5)

        worker.send(:retry_execution?, exception)
      end

      context "when first retry" do
        before do
          allow(task.result).to receive(:metadata).and_return({ retries: 0 })
        end

        it "does not sleep when jitter calculation is 0" do
          expect(worker).not_to receive(:sleep)

          worker.send(:retry_execution?, exception)
        end
      end

      context "when second retry" do
        before do
          allow(task.result).to receive(:metadata).and_return({ retries: 1 })
        end

        it "sleeps for jitter * 1" do
          expect(worker).to receive(:sleep).with(0.5)

          worker.send(:retry_execution?, exception)
        end
      end

      context "when third retry" do
        before do
          allow(task.result).to receive(:metadata).and_return({ retries: 2 })
        end

        it "sleeps for jitter * 2" do
          expect(worker).to receive(:sleep).with(1.0)

          worker.send(:retry_execution?, exception)
        end
      end
    end

    context "with retry_jitter as symbol" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3, retry_jitter: :custom_jitter })
        allow(task.result).to receive(:metadata).and_return({ retries: 1 })
        allow(task).to receive(:custom_jitter).with(1).and_return(2.5)
      end

      it "calls method on task with current retries" do
        expect(task).to receive(:custom_jitter).with(1).and_return(2.5)
        expect(worker).to receive(:sleep).with(2.5)

        worker.send(:retry_execution?, exception)
      end
    end

    context "with retry_jitter as proc" do
      let(:jitter_proc) { ->(retries) { retries * 0.75 } }

      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3, retry_jitter: jitter_proc })
        allow(task.result).to receive(:metadata).and_return({ retries: 2 })
      end

      it "instance_execs proc with current retries" do
        expect(worker).to receive(:sleep).with(1.5)

        worker.send(:retry_execution?, exception)
      end
    end

    context "with retry_jitter as callable object" do
      let(:jitter_callable) do
        Class.new do
          def call(_task, retries)
            retries * 1.25
          end
        end.new
      end

      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3, retry_jitter: jitter_callable })
        allow(task.result).to receive(:metadata).and_return({ retries: 2 })
      end

      it "calls object with task and current retries" do
        expect(jitter_callable).to receive(:call).with(task, 2).and_return(2.5)
        expect(worker).to receive(:sleep).with(2.5)

        worker.send(:retry_execution?, exception)
      end
    end

    context "when jitter calculation returns negative value" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3, retry_jitter: -0.5 })
        allow(task.result).to receive(:metadata).and_return({ retries: 1 })
      end

      it "does not sleep" do
        expect(worker).not_to receive(:sleep)

        worker.send(:retry_execution?, exception)
      end
    end

    context "when jitter calculation returns zero" do
      before do
        allow(task.class).to receive(:settings).and_return({ retries: 3, retry_jitter: 0 })
        allow(task.result).to receive(:metadata).and_return({ retries: 1 })
      end

      it "does not sleep" do
        expect(worker).not_to receive(:sleep)

        worker.send(:retry_execution?, exception)
      end
    end
  end

  describe "#raise_exception" do
    let(:exception) { StandardError.new("test error") }

    it "clears the chain and raises the exception" do
      expect(CMDx::Chain).to receive(:clear).at_least(:once)

      expect { worker.send(:raise_exception, exception) }.to raise_error(exception)
    end
  end

  describe "#invoke_callbacks" do
    let(:callbacks) { instance_double(CMDx::CallbackRegistry) }

    before do
      allow(task.class).to receive(:settings).and_return({ callbacks: callbacks })
    end

    it "delegates to callbacks registry with type and task" do
      expect(callbacks).to receive(:invoke).with(:before_validation, task)

      worker.send(:invoke_callbacks, :before_validation)
    end
  end

  describe "#pre_execution!" do
    let(:callbacks) { instance_double(CMDx::CallbackRegistry) }
    let(:attributes) { instance_double(CMDx::AttributeRegistry) }
    let(:errors) { instance_double(CMDx::Errors) }

    before do
      allow(task.class).to receive(:settings).and_return({
        callbacks: callbacks,
        attributes: attributes
      })
      allow(task).to receive(:errors).and_return(errors)
      allow(callbacks).to receive(:invoke)
      allow(attributes).to receive(:define_and_verify)
    end

    context "when task has no errors" do
      before do
        allow(errors).to receive(:empty?).and_return(true)
      end

      it "invokes before_validation callback and defines attributes" do
        expect(callbacks).to receive(:invoke).with(:before_validation, task)
        expect(attributes).to receive(:define_and_verify).with(task)

        worker.send(:pre_execution!)
      end
    end

    context "when task has errors" do
      before do
        allow(errors).to receive_messages(
          empty?: false,
          to_s: "Validation failed",
          to_h: { name: ["is required"] }
        )
        allow(task.result).to receive(:fail!)
      end

      it "calls fail! on result with error information" do
        expect(task.result).to receive(:fail!).with(
          "Invalid",
          errors: {
            full_message: "Validation failed",
            messages: { name: ["is required"] }
          }
        )

        worker.send(:pre_execution!)
      end
    end
  end

  describe "#execution!" do
    let(:callbacks) { instance_double(CMDx::CallbackRegistry) }

    before do
      allow(task.class).to receive(:settings).and_return({ callbacks: callbacks })
      allow(callbacks).to receive(:invoke)
      allow(task.result).to receive(:executing!)
      allow(task).to receive(:work)
    end

    it "invokes before_execution callback, sets executing state, and calls work" do
      expect(callbacks).to receive(:invoke).with(:before_execution, task)
      expect(task.result).to receive(:executing!)
      expect(task).to receive(:work)

      worker.send(:execution!)
    end
  end

  describe "#post_execution!" do
    let(:callbacks) { instance_double(CMDx::CallbackRegistry) }
    let(:result) { instance_double(CMDx::Result) }

    before do
      allow(task.class).to receive(:settings).and_return({ callbacks: callbacks })
      allow(task).to receive(:result).and_return(result)
      allow(callbacks).to receive(:invoke)
    end

    context "when result is executed and good" do
      before do
        allow(result).to receive_messages(
          state: "complete",
          status: "success",
          executed?: true,
          good?: true,
          bad?: false
        )
      end

      it "invokes all appropriate callbacks" do
        expect(callbacks).to receive(:invoke).with(:on_complete, task)
        expect(callbacks).to receive(:invoke).with(:on_executed, task)
        expect(callbacks).to receive(:invoke).with(:on_success, task)
        expect(callbacks).to receive(:invoke).with(:on_good, task)

        worker.send(:post_execution!)
      end
    end

    context "when result is failed and bad" do
      before do
        allow(result).to receive_messages(
          state: "interrupted",
          status: "failed",
          executed?: false,
          good?: false,
          bad?: true
        )
      end

      it "invokes all appropriate callbacks" do
        expect(callbacks).to receive(:invoke).with(:on_interrupted, task)
        expect(callbacks).to receive(:invoke).with(:on_failed, task)
        expect(callbacks).to receive(:invoke).with(:on_bad, task)

        worker.send(:post_execution!)
      end
    end

    context "when result is skipped" do
      before do
        allow(result).to receive_messages(
          state: "interrupted",
          status: "skipped",
          executed?: false,
          good?: true,
          bad?: false
        )
      end

      it "invokes appropriate callbacks for skipped state" do
        expect(callbacks).to receive(:invoke).with(:on_interrupted, task)
        expect(callbacks).to receive(:invoke).with(:on_skipped, task)
        expect(callbacks).to receive(:invoke).with(:on_good, task)

        worker.send(:post_execution!)
      end
    end
  end

  describe "#finalize_execution!" do
    let(:logger) { instance_double(Logger) }

    before do
      allow(worker).to receive(:freeze_execution!)
      allow(task).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(task.result).to receive(:to_h).and_return({ id: "123", status: "success" })
    end

    it "freezes the task" do
      expect(worker).to receive(:freeze_execution!)

      worker.send(:finalize_execution!)
    end

    it "logs the result information at info level" do
      expect(task).to receive(:logger)
      expect(logger).to receive(:info)

      worker.send(:finalize_execution!)
    end

    context "when logger block is called" do
      it "calls to_h on task result" do
        expect(task.result).to receive(:to_h).and_return({ id: "123", status: "success" })

        expect(logger).to receive(:info) do |&block|
          # When the block is called, it should return the result of to_h
          expect(block.call).to eq({ id: "123", status: "success" })
        end

        worker.send(:finalize_execution!)
      end
    end
  end

  describe "#rollback_execution!" do
    context "when task does not respond to rollback" do
      before do
        allow(task).to receive(:respond_to?).with(:rollback).and_return(false)
        allow(task.result).to receive(:status).and_return("failed")
      end

      it "does not call rollback" do
        expect(task).not_to receive(:rollback)

        worker.send(:rollback_execution!)
      end
    end

    context "when task responds to rollback" do
      before do
        allow(task).to receive(:respond_to?).with(:rollback).and_return(true)
        allow(task).to receive(:rollback)
      end

      context "when rollpoints setting exists" do
        before do
          allow(task.class).to receive(:settings).and_return({ rollback_on: %w[failed skipped] })
        end

        context "when result status is in rollpoints" do
          before do
            allow(task.result).to receive(:status).and_return("failed")
          end

          it "calls rollback" do
            expect(task).to receive(:rollback)

            worker.send(:rollback_execution!)
          end
        end

        context "when result status is not in rollpoints" do
          before do
            allow(task.result).to receive(:status).and_return("success")
          end

          it "does not call rollback" do
            expect(task).not_to receive(:rollback)

            worker.send(:rollback_execution!)
          end
        end
      end

      context "when no rollpoints are configured" do
        before do
          allow(task.class).to receive(:settings).and_return({})
          allow(task.result).to receive(:status).and_return("failed")
        end

        it "does not call rollback" do
          expect(task).not_to receive(:rollback)

          worker.send(:rollback_execution!)
        end
      end

      context "when rollpoints is nil" do
        before do
          allow(task.class).to receive(:settings).and_return({ rollback_on: nil })
          allow(task.result).to receive(:status).and_return("failed")
        end

        it "does not call rollback" do
          expect(task).not_to receive(:rollback)

          worker.send(:rollback_execution!)
        end
      end

      context "with duplicate rollpoints" do
        before do
          allow(task.class).to receive(:settings).and_return({ rollback_on: ["failed", "failed", :failed] })
          allow(task.result).to receive(:status).and_return("failed")
        end

        it "removes duplicates after string conversion and calls rollback" do
          expect(task).to receive(:rollback).once

          worker.send(:rollback_execution!)
        end
      end

      context "with multiple statuses in rollpoints" do
        before do
          allow(task.class).to receive(:settings).and_return({ rollback_on: %w[failed skipped] })
        end

        it "calls rollback when status is failed" do
          allow(task.result).to receive(:status).and_return("failed")

          expect(task).to receive(:rollback)

          worker.send(:rollback_execution!)
        end

        it "calls rollback when status is skipped" do
          allow(task.result).to receive(:status).and_return("skipped")

          expect(task).to receive(:rollback)

          worker.send(:rollback_execution!)
        end
      end
    end
  end
end

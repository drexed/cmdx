# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Worker do
  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:task) { task_class.new }
  let(:worker) { described_class.new(task) }

  describe ".execute" do
    context "when raise is false" do
      it "executes the task without raising exceptions" do
        result = described_class.execute(task, raise: false)
        expect(task.result).to have_been_success
        expect(result).to be_a(Logger)
      end

      context "with failing task" do
        let(:task_class) { create_failing_task(name: "FailingTask", reason: "test failure") }

        it "returns failure result without raising" do
          result = described_class.execute(task, raise: false)
          expect(task.result.failed?).to be true
          expect(task.result.reason).to eq("test failure")
          expect(result).to be_a(Logger)
        end
      end
    end

    context "when raise is true" do
      it "executes the task and may raise exceptions" do
        result = described_class.execute(task, raise: true)
        expect(task.result).to have_been_success
        expect(result).to be_a(Logger)
      end

      context "with failing task" do
        let(:task_class) { create_failing_task(name: "FailingTask", reason: "test failure") }

        it "raises FailFault exception" do
          expect { described_class.execute(task, raise: true) }.to raise_error(CMDx::FailFault)
        end
      end
    end
  end

  describe "#initialize" do
    it "sets the task attribute" do
      expect(worker.task).to eq(task)
    end
  end

  describe "#execute" do
    it "executes successfully and updates task result" do
      worker.execute
      expect(task.result).to have_been_success
    end

    context "when task work method is undefined" do
      let(:task_class) do
        create_task_class(name: "UndefinedWorkTask")
        # Don't define work method, use the default one that raises UndefinedMethodError
      end

      it "raises UndefinedMethodError" do
        expect { worker.execute }.to raise_error(CMDx::UndefinedMethodError)
      end
    end

    context "when task has validation errors" do
      let(:task_class) do
        create_task_class(name: "ValidationTask") do
          required :name
        end
      end

      it "fails with validation errors" do
        worker.execute
        expect(task.result.failed?).to be true
        expect(task.result.reason).to include("name")
      end

      it "calls finalize_execution" do
        allow(worker).to receive(:finalize_execution!)
        worker.execute
        expect(worker).to have_received(:finalize_execution!)
      end
    end

    context "when task raises Fault exception" do
      let(:task_class) { create_failing_task(name: "FaultTask", reason: "fault error") }

      it "handles Fault and sets result status" do
        worker.execute
        expect(task.result.failed?).to be true
        expect(task.result.reason).to eq("fault error")
      end

      it "does not re-raise the exception" do
        expect { worker.execute }.not_to raise_error
      end
    end

    context "when task raises StandardError" do
      let(:task_class) { create_erroring_task(name: "ErrorTask", reason: "standard error") }

      it "handles StandardError and fails task" do
        worker.execute
        expect(task.result.failed?).to be true
        expect(task.result.reason).to eq("[CMDx::TestError] standard error")
        expect(task.result.cause).to be_a(CMDx::TestError)
      end

      it "does not re-raise the exception" do
        expect { worker.execute }.not_to raise_error
      end
    end

    context "when middlewares are configured" do
      let(:middleware) { instance_double("Object", name: "middleware") }

      before do
        allow(task.class.settings[:middlewares]).to receive(:call!).with(task).and_yield
      end

      it "calls middlewares around execution" do
        worker.execute
        expect(task.class.settings[:middlewares]).to have_received(:call!).with(task)
      end
    end

    it "marks result as executed" do
      worker.execute
      expect(task.result.executed?).to be true
    end

    it "calls post_execution callbacks" do
      allow(worker).to receive(:post_execution!)
      worker.execute
      expect(worker).to have_received(:post_execution!)
    end

    it "calls finalize_execution" do
      allow(worker).to receive(:finalize_execution!)
      worker.execute
      expect(worker).to have_received(:finalize_execution!)
    end
  end

  describe "#execute!" do
    context "when task executes successfully" do
      it "executes successfully and updates result" do
        worker.execute!
        expect(task.result).to have_been_success
      end

      it "marks result as executed" do
        worker.execute!
        expect(task.result.executed?).to be true
      end
    end

    context "when task work method is undefined" do
      let(:task_class) do
        create_task_class(name: "UndefinedWorkTask") do
          undef_method :work
        end
      end

      it "raises NoMethodError" do
        expect { worker.execute! }.to raise_error(NoMethodError)
      end

      it "clears the chain" do
        allow(CMDx::Chain).to receive(:clear)
        expect { worker.execute! }.to raise_error(NoMethodError)
        expect(CMDx::Chain).to have_received(:clear).at_least(:once)
      end
    end

    context "when task raises Fault exception" do
      let(:task_class) { create_failing_task(name: "FaultTask", reason: "fault error") }

      context "without breakpoints" do
        before do
          allow(task.class).to receive(:settings).and_return(
            task.class.settings.merge(breakpoints: nil, task_breakpoints: nil)
          )
        end

        it "does not raise exception" do
          expect { worker.execute! }.not_to raise_error
        end

        it "calls post_execution" do
          allow(worker).to receive(:post_execution!)
          worker.execute!
          expect(worker).to have_received(:post_execution!)
        end
      end

      context "with matching breakpoints" do
        before do
          allow(task.class).to receive(:settings).and_return(
            task.class.settings.merge(breakpoints: ["failed"])
          )
        end

        it "raises the exception" do
          expect { worker.execute! }.to raise_error(CMDx::FailFault)
        end

        it "clears the chain" do
          allow(CMDx::Chain).to receive(:clear)
          expect { worker.execute! }.to raise_error(CMDx::FailFault)
          expect(CMDx::Chain).to have_received(:clear).at_least(:once)
        end
      end
    end

    context "when task raises StandardError" do
      let(:task_class) { create_erroring_task(name: "ErrorTask", reason: "standard error") }

      it "raises the exception" do
        expect { worker.execute! }.to raise_error(CMDx::TestError, "standard error")
      end

      it "clears the chain" do
        allow(CMDx::Chain).to receive(:clear)
        expect { worker.execute! }.to raise_error(CMDx::TestError)
        expect(CMDx::Chain).to have_received(:clear).at_least(:once)
      end
    end
  end

  describe "#halt_execution?" do
    let(:fault) { instance_double(CMDx::Fault, result: fault_result) }
    let(:fault_result) { instance_double(CMDx::Result, status: "failed") }

    context "when breakpoints is nil" do
      before do
        allow(task.class).to receive(:settings).and_return(
          task.class.settings.merge(breakpoints: nil, task_breakpoints: nil)
        )
      end

      it "returns false" do
        expect(worker.send(:halt_execution?, fault)).to be false
      end
    end

    context "when breakpoints includes status" do
      before do
        allow(task.class).to receive(:settings).and_return(
          task.class.settings.merge(breakpoints: %w[failed skipped])
        )
      end

      it "returns true" do
        expect(worker.send(:halt_execution?, fault)).to be true
      end
    end

    context "when breakpoints does not include status" do
      before do
        allow(task.class).to receive(:settings).and_return(
          task.class.settings.merge(breakpoints: ["skipped"])
        )
      end

      it "returns false" do
        expect(worker.send(:halt_execution?, fault)).to be false
      end
    end

    context "when using task_breakpoints fallback" do
      before do
        allow(task.class).to receive(:settings).and_return(
          task.class.settings.merge(breakpoints: nil, task_breakpoints: ["failed"])
        )
      end

      it "uses task_breakpoints" do
        expect(worker.send(:halt_execution?, fault)).to be true
      end
    end
  end

  describe "#raise_exception" do
    let(:exception) { StandardError.new("test error") }

    it "clears the chain and raises exception" do
      allow(CMDx::Chain).to receive(:clear)
      expect { worker.send(:raise_exception, exception) }.to raise_error(StandardError, "test error")
      expect(CMDx::Chain).to have_received(:clear).at_least(:once)
    end
  end

  describe "#invoke_callbacks" do
    let(:callback_registry) { instance_double(CMDx::CallbackRegistry) }

    before do
      allow(task.class.settings[:callbacks]).to receive(:invoke)
    end

    it "invokes callbacks with type and task" do
      worker.send(:invoke_callbacks, :before_execution)
      expect(task.class.settings[:callbacks]).to have_received(:invoke).with(:before_execution, task)
    end
  end

  describe "#pre_execution!" do
    it "invokes before_validation callbacks" do
      allow(worker).to receive(:invoke_callbacks)
      worker.send(:pre_execution!)
      expect(worker).to have_received(:invoke_callbacks).with(:before_validation)
    end

    it "defines and verifies attributes" do
      attribute_registry = task.class.settings[:attributes]
      allow(attribute_registry).to receive(:define_and_verify)
      worker.send(:pre_execution!)
      expect(attribute_registry).to have_received(:define_and_verify).with(task)
    end

    context "when task has errors" do
      before do
        task.errors.add(:test, "validation error")
      end

      it "fails the task with errors and raises FailFault" do
        expect { worker.send(:pre_execution!) }.to raise_error(CMDx::FailFault) do |error|
          expect(error.result.failed?).to be true
          expect(error.result.reason).to include("validation error")
        end
      end
    end

    context "when task has no errors" do
      it "does not fail the task" do
        worker.send(:pre_execution!)
        expect(task.result.success?).to be true
      end
    end
  end

  describe "#execution!" do
    it "invokes before_execution callbacks" do
      allow(worker).to receive(:invoke_callbacks)
      worker.send(:execution!)
      expect(worker).to have_received(:invoke_callbacks).with(:before_execution)
    end

    it "sets result to executing state" do
      worker.send(:execution!)
      expect(task.result.executing?).to be true
    end

    it "calls task work method" do
      allow(task).to receive(:work)
      worker.send(:execution!)
      expect(task).to have_received(:work)
    end
  end

  describe "#post_execution!" do
    context "when task result is successful" do
      it "invokes state-specific callbacks" do
        allow(worker).to receive(:invoke_callbacks)
        task.result.executing!
        task.result.complete!
        worker.send(:post_execution!)
        expect(worker).to have_received(:invoke_callbacks).with(:on_complete)
        expect(worker).to have_received(:invoke_callbacks).with(:on_executed)
        expect(worker).to have_received(:invoke_callbacks).with(:on_success)
        expect(worker).to have_received(:invoke_callbacks).with(:on_good)
      end
    end

    context "when task result is failed" do
      before do
        task.result.fail!("test failure", halt: false)
      end

      it "invokes appropriate callbacks" do
        allow(worker).to receive(:invoke_callbacks)
        worker.send(:post_execution!)
        expect(worker).to have_received(:invoke_callbacks).with(:on_interrupted)
        expect(worker).to have_received(:invoke_callbacks).with(:on_failed)
        expect(worker).to have_received(:invoke_callbacks).with(:on_bad)
      end
    end

    context "when task result is skipped" do
      before do
        task.result.skip!("test skip", halt: false)
      end

      it "invokes appropriate callbacks" do
        allow(worker).to receive(:invoke_callbacks)
        worker.send(:post_execution!)
        expect(worker).to have_received(:invoke_callbacks).with(:on_interrupted)
        expect(worker).to have_received(:invoke_callbacks).with(:on_skipped)
        expect(worker).to have_received(:invoke_callbacks).with(:on_good)
      end
    end
  end

  describe "#finalize_execution!" do
    let(:logger) { instance_double(Logger) }

    before do
      allow(task).to receive(:logger).and_return(logger)
      allow(logger).to receive(:tap).and_yield(logger)
      allow(logger).to receive(:with_level).with(:info).and_yield
      allow(logger).to receive(:info)
      allow(CMDx::Freezer).to receive(:immute)
    end

    it "freezes the task" do
      worker.send(:finalize_execution!)
      expect(CMDx::Freezer).to have_received(:immute).with(task)
    end

    it "logs the result" do
      worker.send(:finalize_execution!)
      expect(logger).to have_received(:with_level).with(:info)
      expect(logger).to have_received(:info)
    end
  end
end

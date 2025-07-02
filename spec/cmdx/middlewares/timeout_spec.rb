# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Timeout do
  subject(:middleware) { described_class.new(options) }

  let(:options) { {} }
  let(:task) { double("task", __cmdx_eval: true, __cmdx_yield: nil, fail!: nil, result: failed_result) }
  let(:callable) { double("callable") }
  let(:result) { double("result") }
  let(:failed_result) { double("failed_result") }

  before do
    allow(callable).to receive(:call).with(task).and_return(result)
    allow(Timeout).to receive(:timeout).and_yield
  end

  describe "#initialize" do
    context "with no options" do
      it "sets seconds to default value of 3" do
        expect(middleware.seconds).to eq(3)
      end

      it "sets conditional to empty hash" do
        expect(middleware.conditional).to eq({})
      end
    end

    context "with seconds option" do
      let(:options) { { seconds: 30 } }

      it "sets seconds to provided value" do
        expect(middleware.seconds).to eq(30)
      end
    end

    context "with float seconds" do
      let(:options) { { seconds: 2.5 } }

      it "sets seconds to provided float value" do
        expect(middleware.seconds).to eq(2.5)
      end
    end

    context "with symbol seconds" do
      let(:options) { { seconds: :timeout_method } }

      it "sets seconds to provided symbol" do
        expect(middleware.seconds).to eq(:timeout_method)
      end
    end

    context "with proc seconds" do
      let(:timeout_proc) { proc { 45 } }
      let(:options) { { seconds: timeout_proc } }

      it "sets seconds to provided proc" do
        expect(middleware.seconds).to eq(timeout_proc)
      end
    end

    context "with conditional options" do
      let(:options) { { if: :enabled?, unless: :disabled? } }

      it "extracts conditional options" do
        expect(middleware.conditional).to eq({ if: :enabled?, unless: :disabled? })
      end
    end

    context "with mixed options" do
      let(:options) { { seconds: 60, if: :active?, other: "ignored" } }

      it "sets seconds correctly" do
        expect(middleware.seconds).to eq(60)
      end

      it "extracts only conditional options" do
        expect(middleware.conditional).to eq({ if: :active? })
      end
    end
  end

  describe "#call" do
    context "when conditions are not met" do
      before do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(false)
      end

      it "calls the callable without timeout protection" do
        actual_result = middleware.call(task, callable)

        expect(callable).to have_received(:call).with(task)
        expect(Timeout).not_to have_received(:timeout)
        expect(actual_result).to eq(result)
      end
    end

    context "when conditions are met" do
      before do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(true)
      end

      context "with default timeout" do
        before do
          allow(task).to receive(:__cmdx_yield).with(3).and_return(3)
        end

        it "applies default 3 second timeout" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(3, CMDx::TimeoutError, "execution exceeded 3 seconds")
        end

        it "calls the callable within timeout block" do
          middleware.call(task, callable)

          expect(callable).to have_received(:call).with(task)
        end

        it "returns the callable result" do
          actual_result = middleware.call(task, callable)

          expect(actual_result).to eq(result)
        end
      end

      context "with explicit timeout value" do
        let(:options) { { seconds: 30 } }

        before do
          allow(task).to receive(:__cmdx_yield).with(30).and_return(30)
        end

        it "applies specified timeout" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(30, CMDx::TimeoutError, "execution exceeded 30 seconds")
        end
      end

      context "with float timeout value" do
        let(:options) { { seconds: 2.5 } }

        before do
          allow(task).to receive(:__cmdx_yield).with(2.5).and_return(2.5)
        end

        it "applies float timeout" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(2.5, CMDx::TimeoutError, "execution exceeded 2.5 seconds")
        end
      end

      context "with proc-based timeout" do
        let(:options) { { seconds: proc { 45 } } }

        before do
          allow(task).to receive(:__cmdx_yield).with(options[:seconds]).and_return(45)
        end

        it "uses result from proc execution" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(45, CMDx::TimeoutError, "execution exceeded 45 seconds")
        end
      end

      context "with method-based timeout" do
        let(:options) { { seconds: :timeout_method } }

        before do
          allow(task).to receive(:__cmdx_yield).with(:timeout_method).and_return(60)
        end

        it "uses result from method call" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(60, CMDx::TimeoutError, "execution exceeded 60 seconds")
        end
      end

      context "when timeout value yields nil" do
        let(:options) { { seconds: :missing_method } }

        before do
          allow(task).to receive(:__cmdx_yield).with(:missing_method).and_return(nil)
        end

        it "falls back to default timeout of 3 seconds" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(3, CMDx::TimeoutError, "execution exceeded 3 seconds")
        end
      end

      context "with conditional execution" do
        let(:options) { { seconds: 25, if: :enabled?, unless: :disabled? } }

        before do
          allow(task).to receive(:__cmdx_eval).with({ if: :enabled?, unless: :disabled? }).and_return(true)
          allow(task).to receive(:__cmdx_yield).with(25).and_return(25)
        end

        it "evaluates conditions before applying timeout" do
          middleware.call(task, callable)

          expect(task).to have_received(:__cmdx_eval).with({ if: :enabled?, unless: :disabled? })
          expect(Timeout).to have_received(:timeout)
        end
      end

      context "when timeout is exceeded" do
        let(:options) { { seconds: 5 } }
        let(:timeout_error) { CMDx::TimeoutError.new("execution exceeded 5 seconds") }

        before do
          allow(task).to receive(:__cmdx_yield).with(5).and_return(5)
          allow(Timeout).to receive(:timeout).and_raise(timeout_error)
        end

        it "catches timeout error and fails the task" do
          result = middleware.call(task, callable)

          expect(task).to have_received(:fail!).with(
            reason: "[CMDx::TimeoutError] execution exceeded 5 seconds",
            original_exception: timeout_error,
            seconds: 5
          )
          expect(result).to eq(failed_result)
        end

        it "returns the task result" do
          result = middleware.call(task, callable)

          expect(result).to eq(failed_result)
        end
      end

      context "when other exceptions occur" do
        let(:error) { StandardError.new("other error") }

        before do
          allow(task).to receive(:__cmdx_yield).with(3).and_return(3)
          allow(callable).to receive(:call).and_raise(error)
        end

        it "allows other exceptions to propagate" do
          expect { middleware.call(task, callable) }.to raise_error(StandardError, "other error")
        end
      end

      context "with zero timeout" do
        let(:options) { { seconds: 0 } }

        before do
          allow(task).to receive(:__cmdx_yield).with(0).and_return(0)
        end

        it "applies zero timeout" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(0, CMDx::TimeoutError, "execution exceeded 0 seconds")
        end
      end

      context "with negative timeout" do
        let(:options) { { seconds: -1 } }

        before do
          allow(task).to receive(:__cmdx_yield).with(-1).and_return(-1)
        end

        it "applies negative timeout" do
          middleware.call(task, callable)

          expect(Timeout).to have_received(:timeout).with(-1, CMDx::TimeoutError, "execution exceeded -1 seconds")
        end
      end
    end

    context "with complex timeout resolution" do
      before do
        allow(task).to receive(:__cmdx_eval).with({}).and_return(true)
      end

      it "uses explicit timeout when available" do
        allow(task).to receive(:__cmdx_yield).with(15).and_return(15)

        middleware_with_timeout = described_class.new(seconds: 15)
        middleware_with_timeout.call(task, callable)

        expect(Timeout).to have_received(:timeout).with(15, CMDx::TimeoutError, "execution exceeded 15 seconds")
      end

      it "falls back to default when yield returns nil" do
        allow(task).to receive(:__cmdx_yield).with(:missing).and_return(nil)

        middleware_with_missing = described_class.new(seconds: :missing)
        middleware_with_missing.call(task, callable)

        expect(Timeout).to have_received(:timeout).with(3, CMDx::TimeoutError, "execution exceeded 3 seconds")
      end
    end
  end

  describe "inheritance" do
    it "inherits from CMDx::Middleware" do
      expect(described_class).to be < CMDx::Middleware
    end
  end

  describe "attribute readers" do
    let(:options) { { seconds: 42, if: :condition } }

    it "provides access to seconds" do
      expect(middleware.seconds).to eq(42)
    end

    it "provides access to conditional options" do
      expect(middleware.conditional).to eq({ if: :condition })
    end
  end

  describe "timeout error class" do
    it "defines TimeoutError as a subclass of Interrupt" do
      expect(CMDx::TimeoutError).to be < Interrupt
    end

    it "can be instantiated with a message" do
      error = CMDx::TimeoutError.new("test message")

      expect(error.message).to eq("test message")
    end
  end
end

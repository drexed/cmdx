# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Middlewares::Timeout, type: :unit do
  subject(:timeout_middleware) { described_class }

  let(:task) { double("CMDx::Task", result: result) } # rubocop:disable RSpec/VerifiedDoubles
  let(:result) { instance_double(CMDx::Result) }
  let(:block_result) { "block executed" }
  let(:test_block) { proc { block_result } }

  before do
    allow(result).to receive(:fail!)
    allow(result).to receive(:tap).and_return(result)
  end

  describe ".call" do
    context "when seconds option is a Numeric" do
      it "uses the numeric value as timeout limit" do
        expect(Timeout).to receive(:timeout).with(5, CMDx::TimeoutError, "execution exceeded 5 seconds").and_yield.and_return(block_result)

        result = timeout_middleware.call(task, seconds: 5, &test_block)

        expect(result).to eq(block_result)
      end

      it "handles float values" do
        expect(Timeout).to receive(:timeout).with(2.5, CMDx::TimeoutError, "execution exceeded 2.5 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: 2.5, &test_block)
      end

      it "handles zero timeout" do
        expect(Timeout).to receive(:timeout).with(0, CMDx::TimeoutError, "execution exceeded 0 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: 0, &test_block)
      end
    end

    context "when seconds option is a Symbol" do
      let(:method_name) { :timeout_value }

      before do
        allow(task).to receive(:send).with(method_name).and_return(10)
      end

      it "calls the method on the task and uses the result" do
        allow(task).to receive(:send).with(method_name).and_return(10)

        expect(Timeout).to receive(:timeout).with(10, CMDx::TimeoutError, "execution exceeded 10 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: method_name, &test_block)
      end

      it "passes non-numeric method return values directly to timeout" do
        allow(task).to receive(:send).with(method_name).and_return("invalid")

        expect(Timeout).to receive(:timeout).with("invalid", CMDx::TimeoutError, "execution exceeded invalid seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: method_name, &test_block)
      end
    end

    context "when seconds option is a Proc" do
      let(:timeout_proc) { proc { 15 } }

      before do
        allow(task).to receive(:instance_eval).and_yield.and_return(15)
      end

      it "evaluates the proc in task context and uses the result" do
        expect(task).to receive(:instance_eval).and_yield.and_return(15)

        expect(Timeout).to receive(:timeout).with(15, CMDx::TimeoutError, "execution exceeded 15 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: timeout_proc, &test_block)
      end

      it "passes non-numeric proc return values directly to timeout" do
        expect(task).to receive(:instance_eval).and_yield.and_return(nil)

        expect(Timeout).to receive(:timeout).with(nil, CMDx::TimeoutError, "execution exceeded  seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: timeout_proc, &test_block)
      end
    end

    context "when seconds option responds to call" do
      let(:callable) { instance_double("MockCallable", call: 20) }

      it "calls the callable with the task and uses the result" do
        allow(callable).to receive(:call).with(task).and_return(20)

        expect(Timeout).to receive(:timeout).with(20, CMDx::TimeoutError, "execution exceeded 20 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: callable, &test_block)
      end

      it "passes non-numeric callable return values directly to timeout" do
        allow(callable).to receive(:call).with(task).and_return(false)

        expect(Timeout).to receive(:timeout).with(false, CMDx::TimeoutError, "execution exceeded false seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: callable, &test_block)
      end
    end

    context "when seconds option is nil" do
      it "uses the default timeout limit" do
        expect(Timeout).to receive(:timeout).with(described_class::DEFAULT_LIMIT, CMDx::TimeoutError, "execution exceeded 3 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: nil, &test_block)
      end
    end

    context "when seconds option is false" do
      it "uses the default timeout limit" do
        expect(Timeout).to receive(:timeout).with(described_class::DEFAULT_LIMIT, CMDx::TimeoutError, "execution exceeded 3 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: false, &test_block)
      end
    end

    context "when no seconds option is provided" do
      it "uses the default timeout limit" do
        expect(Timeout).to receive(:timeout).with(described_class::DEFAULT_LIMIT, CMDx::TimeoutError, "execution exceeded 3 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, &test_block)
      end
    end

    context "when seconds option is an unsupported type" do
      it "uses the default timeout limit for string values" do
        expect(Timeout).to receive(:timeout).with(described_class::DEFAULT_LIMIT, CMDx::TimeoutError, "execution exceeded 3 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: "invalid", &test_block)
      end

      it "uses the default timeout limit for array values" do
        expect(Timeout).to receive(:timeout).with(described_class::DEFAULT_LIMIT, CMDx::TimeoutError, "execution exceeded 3 seconds").and_yield.and_return(block_result)

        timeout_middleware.call(task, seconds: [1, 2, 3], &test_block)
      end
    end

    context "when block execution succeeds" do
      it "returns the block result" do
        allow(Timeout).to receive(:timeout).and_yield.and_return(block_result)

        result = timeout_middleware.call(task, seconds: 5, &test_block)

        expect(result).to eq(block_result)
      end

      it "returns nil when block returns nil" do
        nil_block = proc {}
        allow(Timeout).to receive(:timeout).and_yield.and_return(nil)

        result = timeout_middleware.call(task, seconds: 5, &nil_block)

        expect(result).to be_nil
      end

      it "returns false when block returns false" do
        false_block = proc { false }
        allow(Timeout).to receive(:timeout).and_yield.and_return(false)

        result = timeout_middleware.call(task, seconds: 5, &false_block)

        expect(result).to be(false)
      end
    end

    context "when block raises other errors" do
      let(:standard_error) { StandardError.new("unexpected error") }
      let(:error_block) { proc { raise standard_error } }

      it "re-raises non-timeout errors without calling fail!" do
        expect(Timeout).to receive(:timeout).and_yield.and_raise(standard_error)

        expect(result).not_to receive(:fail!)

        expect do
          timeout_middleware.call(task, seconds: 5, &error_block)
        end.to raise_error(StandardError, "unexpected error")
      end
    end

    context "with conditional execution using 'if'" do
      before do
        allow(task).to receive(:should_timeout?).and_return(true)
        allow(Timeout).to receive(:timeout)
      end

      it "executes timeout when 'if' condition is true" do
        expect(Timeout).to receive(:timeout).with(5, CMDx::TimeoutError, "execution exceeded 5 seconds").and_yield.and_return(block_result)

        result = timeout_middleware.call(task, seconds: 5, if: :should_timeout?, &test_block)

        expect(result).to eq(block_result)
      end

      it "skips timeout when 'if' condition is false" do
        allow(task).to receive(:should_timeout?).and_return(false)
        expect(Timeout).not_to receive(:timeout)

        result = timeout_middleware.call(task, seconds: 5, if: :should_timeout?, &test_block)

        expect(result).to eq(block_result)
      end
    end

    context "with conditional execution using 'unless'" do
      before do
        allow(task).to receive(:skip_timeout?).and_return(false)
        allow(Timeout).to receive(:timeout)
      end

      it "executes timeout when 'unless' condition is false" do
        expect(Timeout).to receive(:timeout).with(5, CMDx::TimeoutError, "execution exceeded 5 seconds").and_yield.and_return(block_result)

        result = timeout_middleware.call(task, seconds: 5, unless: :skip_timeout?, &test_block)

        expect(result).to eq(block_result)
      end

      it "skips timeout when 'unless' condition is true" do
        allow(task).to receive(:skip_timeout?).and_return(true)

        expect(Timeout).not_to receive(:timeout)

        result = timeout_middleware.call(task, seconds: 5, unless: :skip_timeout?, &test_block)

        expect(result).to eq(block_result)
      end
    end

    context "with additional options" do
      it "ignores unknown options" do
        expect(Timeout).to receive(:timeout).with(5, CMDx::TimeoutError, "execution exceeded 5 seconds").and_yield.and_return(block_result)

        expect do
          timeout_middleware.call(task, seconds: 5, unknown_option: "value", &test_block)
        end.not_to raise_error
      end
    end
  end

  describe "CMDx::TimeoutError" do
    it "is a subclass of Interrupt" do
      expect(CMDx::TimeoutError.superclass).to eq(Interrupt)
    end

    it "can be instantiated with a message" do
      error = CMDx::TimeoutError.new("test timeout")
      expect(error.message).to eq("test timeout")
    end
  end
end

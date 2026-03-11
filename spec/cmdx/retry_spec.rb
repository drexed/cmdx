# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Retry, type: :unit do
  subject(:retry_instance) { described_class.new(task) }

  let(:task_class) { create_successful_task(name: "RetryTask") }
  let(:task) { task_class.new }

  describe "#initialize" do
    it "assigns the task" do
      expect(retry_instance.task).to eq(task)
    end

    it "provides read access to task attribute" do
      expect(described_class.instance_methods).to include(:task)
      expect(described_class.private_instance_methods).not_to include(:task)
    end
  end

  describe "#available" do
    context "when retries is configured" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 3))
      end

      it "returns the configured retry count" do
        expect(retry_instance.available).to eq(3)
      end
    end

    context "when retries is nil" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: nil))
      end

      it "returns 0" do
        expect(retry_instance.available).to eq(0)
      end
    end

    context "when retries is not configured" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings)
      end

      it "returns 0" do
        expect(retry_instance.available).to eq(0)
      end
    end
  end

  describe "#available?" do
    context "when retries are configured" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 2))
      end

      it "returns true" do
        expect(retry_instance.available?).to be(true)
      end
    end

    context "when retries is 0" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 0))
      end

      it "returns false" do
        expect(retry_instance.available?).to be(false)
      end
    end

    context "when retries is nil" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: nil))
      end

      it "returns false" do
        expect(retry_instance.available?).to be(false)
      end
    end
  end

  describe "#attempts" do
    context "when no retries have occurred" do
      it "returns 0" do
        expect(retry_instance.attempts).to eq(0)
      end
    end

    context "when retries have occurred" do
      before do
        task.result.retries = 2
      end

      it "returns the number of attempts" do
        expect(retry_instance.attempts).to eq(2)
      end
    end
  end

  describe "#retried?" do
    context "when no retries have occurred" do
      it "returns false" do
        expect(retry_instance.retried?).to be(false)
      end
    end

    context "when at least one retry has occurred" do
      before do
        task.result.retries = 1
      end

      it "returns true" do
        expect(retry_instance.retried?).to be(true)
      end
    end
  end

  describe "#remaining" do
    before do
      allow(task.class).to receive(:settings).and_return(mock_settings(retries: 5))
    end

    context "when no retries have occurred" do
      it "returns the full retry count" do
        expect(retry_instance.remaining).to eq(5)
      end
    end

    context "when some retries have occurred" do
      before do
        task.result.retries = 2
      end

      it "returns the difference between available and attempts" do
        expect(retry_instance.remaining).to eq(3)
      end
    end

    context "when all retries are exhausted" do
      before do
        task.result.retries = 5
      end

      it "returns 0" do
        expect(retry_instance.remaining).to eq(0)
      end
    end
  end

  describe "#remaining?" do
    before do
      allow(task.class).to receive(:settings).and_return(mock_settings(retries: 3))
    end

    context "when retries remain" do
      it "returns true" do
        expect(retry_instance.remaining?).to be(true)
      end
    end

    context "when all retries are exhausted" do
      before do
        task.result.retries = 3
      end

      it "returns false" do
        expect(retry_instance.remaining?).to be(false)
      end
    end
  end

  describe "#exceptions" do
    context "when retry_on is configured with specific exceptions" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retry_on: [ArgumentError, RuntimeError]))
      end

      it "returns the configured exception classes" do
        expect(retry_instance.exceptions).to eq([ArgumentError, RuntimeError])
      end
    end

    context "when retry_on is a single exception class" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retry_on: ArgumentError))
      end

      it "wraps it in an array" do
        expect(retry_instance.exceptions).to eq([ArgumentError])
      end
    end

    context "when retry_on is nil" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retry_on: nil))
      end

      it "defaults to StandardError" do
        expect(retry_instance.exceptions).to eq([StandardError])
      end
    end

    context "when retry_on is not configured" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings)
      end

      it "defaults to StandardError" do
        expect(retry_instance.exceptions).to eq([StandardError])
      end
    end

    it "memoizes the result" do
      allow(task.class).to receive(:settings).and_return(mock_settings(retry_on: [ArgumentError]))

      first_call = retry_instance.exceptions
      second_call = retry_instance.exceptions

      expect(first_call).to equal(second_call)
    end
  end

  describe "#exception?" do
    context "with default retry_on (StandardError)" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retry_on: nil))
      end

      it "returns true for StandardError" do
        expect(retry_instance.exception?(StandardError.new)).to be(true)
      end

      it "returns true for subclass of StandardError" do
        expect(retry_instance.exception?(ArgumentError.new)).to be(true)
      end

      it "returns false for non-matching exception" do
        expect(retry_instance.exception?(Exception.new)).to be(false)
      end
    end

    context "with specific retry_on" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retry_on: [ArgumentError]))
      end

      it "returns true for exact match" do
        expect(retry_instance.exception?(ArgumentError.new)).to be(true)
      end

      it "returns false for non-matching exception" do
        expect(retry_instance.exception?(RuntimeError.new)).to be(false)
      end

      it "returns false for parent class of configured exception" do
        expect(retry_instance.exception?(StandardError.new)).to be(false)
      end
    end

    context "with multiple retry_on exceptions" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retry_on: [ArgumentError, RuntimeError]))
      end

      it "returns true when matching any configured exception" do
        expect(retry_instance.exception?(ArgumentError.new)).to be(true)
        expect(retry_instance.exception?(RuntimeError.new)).to be(true)
      end
    end
  end

  describe "#wait" do
    context "with numeric jitter" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 3, retry_jitter: 0.5))
      end

      it "returns jitter multiplied by attempts" do
        task.result.retries = 2

        expect(retry_instance.wait).to eq(1.0)
      end

      it "returns 0.0 when no attempts have been made" do
        expect(retry_instance.wait).to eq(0.0)
      end
    end

    context "with symbol jitter" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 3, retry_jitter: :custom_wait))
        allow(task).to receive(:custom_wait).with(1).and_return(2.5)
        task.result.retries = 1
      end

      it "calls the named method on the task with attempts" do
        expect(task).to receive(:custom_wait).with(1)

        retry_instance.wait
      end

      it "returns the method result as a float" do
        expect(retry_instance.wait).to eq(2.5)
      end
    end

    context "with proc jitter" do
      let(:jitter_proc) { ->(retries) { retries * 0.75 } }

      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 3, retry_jitter: jitter_proc))
        task.result.retries = 2
      end

      it "instance_execs the proc with attempts" do
        expect(retry_instance.wait).to eq(1.5)
      end
    end

    context "with callable object jitter" do
      let(:jitter_callable) do
        Class.new do
          def call(_task, retries)
            retries * 1.25
          end
        end.new
      end

      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 3, retry_jitter: jitter_callable))
        task.result.retries = 2
      end

      it "calls the object with task and attempts" do
        expect(jitter_callable).to receive(:call).with(task, 2).and_call_original

        retry_instance.wait
      end

      it "returns the callable result as a float" do
        expect(retry_instance.wait).to eq(2.5)
      end
    end

    context "with nil jitter" do
      before do
        allow(task.class).to receive(:settings).and_return(mock_settings(retries: 3, retry_jitter: nil))
        task.result.retries = 2
      end

      it "returns 0.0" do
        expect(retry_instance.wait).to eq(0.0)
      end
    end
  end
end

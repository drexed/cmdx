# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Repeator, type: :unit do
  subject(:repeator) { described_class.new(task) }

  let(:task_class) { create_task_class(name: "TestTask") }
  let(:task) { task_class.new }
  let(:exception) { StandardError.new("test error") }

  describe "#initialize" do
    it "sets the task attribute" do
      expect(repeator.task).to eq(task)
    end

    it "initializes exception as nil" do
      expect(repeator.exception).to be_nil
    end
  end

  describe "#retry?" do
    let(:check) { repeator.retry?(exception) }

    context "when retries are not configured" do
      before do
        allow(task_class).to receive(:settings).and_return({})
      end

      it "returns false" do
        expect(check).to be false
      end

      it "sets the exception" do
        check
        expect(repeator.exception).to eq(exception)
      end
    end

    context "when retries are configured but exhausted" do
      before do
        allow(task_class).to receive(:settings).and_return(retries: 2)
        allow(task.result.metadata).to receive(:[]).with(:retries).and_return(2)
        allow(task.result.metadata).to receive(:[]=)
      end

      it "returns false" do
        expect(check).to be false
      end
    end

    context "when retries are available and remaining" do
      before do
        allow(task_class).to receive(:settings).and_return(retries: 3)
        allow(task.result.metadata).to receive(:[]).with(:retries).and_return(1)
        allow(task.result.metadata).to receive(:[]=)
        allow(repeator).to receive(:retriable_exception?).and_return(true)
        allow(repeator).to receive(:log_current_attempt)
        allow(repeator).to receive(:delay_next_attempt)
      end

      it "returns true" do
        expect(check).to be true
      end

      it "sets the exception" do
        check
        expect(repeator.exception).to eq(exception)
      end

      it "increments retry count" do
        expect(task.result.metadata).to receive(:[]=).with(:retries, 2)
        check
      end

      it "logs the current attempt" do
        expect(repeator).to receive(:log_current_attempt)
        check
      end

      it "delays the next attempt" do
        expect(repeator).to receive(:delay_next_attempt)
        check
      end
    end

    context "when exception is not retriable" do
      before do
        allow(task_class).to receive(:settings).and_return(retries: 3, retry_on: ArgumentError)
        allow(task.result.metadata).to receive(:[]).with(:retries).and_return(0)
      end

      it "returns false" do
        expect(check).to be false
      end
    end

    context "when retry_on is configured with multiple exception types" do
      before do
        allow(task_class).to receive(:settings).and_return(retries: 3, retry_on: [StandardError, ArgumentError])
        allow(task.result.metadata).to receive(:[]).with(:retries).and_return(0)
        allow(task.result.metadata).to receive(:[]=)
        allow(repeator).to receive(:log_current_attempt)
        allow(repeator).to receive(:delay_next_attempt)
      end

      it "returns true for matching exception" do
        expect(check).to be true
      end
    end

    context "when retry_on is configured with a single exception type" do
      before do
        allow(task_class).to receive(:settings).and_return(retries: 3, retry_on: StandardError)
        allow(task.result.metadata).to receive(:[]).with(:retries).and_return(0)
        allow(task.result.metadata).to receive(:[]=)
        allow(repeator).to receive(:log_current_attempt)
        allow(repeator).to receive(:delay_next_attempt)
      end

      it "returns true for matching exception" do
        expect(check).to be true
      end
    end

    context "when retry_on is not configured" do
      before do
        allow(task_class).to receive(:settings).and_return(retries: 3)
        allow(task.result.metadata).to receive(:[]).with(:retries).and_return(0)
        allow(task.result.metadata).to receive(:[]=)
        allow(repeator).to receive(:log_current_attempt)
        allow(repeator).to receive(:delay_next_attempt)
      end

      it "defaults to StandardError" do
        expect(check).to be true
      end
    end
  end
end

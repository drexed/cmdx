# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultSerializer do
  describe ".call" do
    let(:task) { create_simple_task(name: "TestTask").new }
    let(:result) { CMDx::Result.new(task) }
    let(:mock_task_serializer) do
      {
        index: 0,
        chain_id: "abc123",
        type: "Task",
        class: "TestTask",
        id: "def456",
        tags: []
      }
    end

    before do
      allow(CMDx::TaskSerializer).to receive(:call).with(task).and_return(mock_task_serializer)
      allow(result).to receive(:runtime).and_return(0.05)
    end

    context "with successful result" do
      it "returns hash with task and result data" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          index: 0,
          chain_id: "abc123",
          type: "Task",
          class: "TestTask",
          id: "def456",
          tags: [],
          state: "initialized",
          status: "success",
          outcome: "initialized",
          metadata: {},
          runtime: 0.05
        )
      end

      it "does not include failure fields" do
        serialized = described_class.call(result)

        expect(serialized).not_to have_key(:caused_failure)
        expect(serialized).not_to have_key(:threw_failure)
      end

      it "delegates to TaskSerializer" do
        described_class.call(result)

        expect(CMDx::TaskSerializer).to have_received(:call).with(task)
      end
    end

    context "with executed successful result" do
      before do
        result.executing!
        result.complete!
      end

      it "returns complete state and success status" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          state: "complete",
          status: "success",
          outcome: "success"
        )
      end
    end

    context "with skipped result" do
      before do
        result.skip!(reason: "condition not met", original_exception: StandardError.new)
      end

      it "returns skipped status with metadata" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          state: "initialized",
          status: "skipped",
          outcome: "initialized"
        )
        expect(serialized[:metadata]).to include(reason: "condition not met")
        expect(serialized[:metadata]).to have_key(:original_exception)
      end

      it "does not include failure fields for skipped result" do
        serialized = described_class.call(result)

        expect(serialized).not_to have_key(:caused_failure)
        expect(serialized).not_to have_key(:threw_failure)
      end
    end

    context "with failed result" do
      let(:mock_caused_failure) { { class: "CausedTask", state: "interrupted", status: "failed" } }
      let(:mock_threw_failure) { { class: "ThrewTask", state: "interrupted", status: "failed" } }

      before do
        result.fail!(error: "validation failed", original_exception: StandardError.new)

        allow(result).to receive_messages(caused_failure?: false, threw_failure?: false, caused_failure: double("caused_result", to_h: mock_caused_failure.merge(caused_failure: "nested", threw_failure: "nested")), threw_failure: double("threw_result", to_h: mock_threw_failure.merge(caused_failure: "nested", threw_failure: "nested")))
      end

      it "returns failed status with metadata" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          state: "initialized",
          status: "failed",
          outcome: "initialized"
        )
        expect(serialized[:metadata]).to include(error: "validation failed")
        expect(serialized[:metadata]).to have_key(:original_exception)
      end

      it "includes stripped caused_failure" do
        serialized = described_class.call(result)

        expect(serialized[:caused_failure]).to eq(
          class: "CausedTask",
          state: "interrupted",
          status: "failed"
        )
      end

      it "includes stripped threw_failure" do
        serialized = described_class.call(result)

        expect(serialized[:threw_failure]).to eq(
          class: "ThrewTask",
          state: "interrupted",
          status: "failed"
        )
      end

      it "strips caused_failure and threw_failure from nested results" do
        serialized = described_class.call(result)

        expect(serialized[:caused_failure]).not_to have_key(:caused_failure)
        expect(serialized[:caused_failure]).not_to have_key(:threw_failure)
        expect(serialized[:threw_failure]).not_to have_key(:caused_failure)
        expect(serialized[:threw_failure]).not_to have_key(:threw_failure)
      end
    end

    context "with executed failed result" do
      before do
        result.executing!
        result.fail!(error: "execution error", original_exception: StandardError.new)
        result.executed!
      end

      it "returns interrupted state and failed status" do
        serialized = described_class.call(result)

        expect(serialized).to include(
          state: "interrupted",
          status: "failed",
          outcome: "interrupted"
        )
      end
    end

    context "with different metadata types" do
      it "handles empty metadata" do
        serialized = described_class.call(result)

        expect(serialized[:metadata]).to eq({})
      end

      it "handles complex metadata" do
        result.fail!(
          error: "validation failed",
          details: { field: "email", value: "invalid" },
          timestamp: Time.now,
          original_exception: StandardError.new
        )

        serialized = described_class.call(result)

        expect(serialized[:metadata]).to include(
          error: "validation failed",
          details: { field: "email", value: "invalid" }
        )
        expect(serialized[:metadata]).to have_key(:timestamp)
      end
    end

    context "with runtime variations" do
      it "handles nil runtime" do
        allow(result).to receive(:runtime).and_return(nil)

        serialized = described_class.call(result)

        expect(serialized[:runtime]).to be_nil
      end

      it "handles zero runtime" do
        allow(result).to receive(:runtime).and_return(0.0)

        serialized = described_class.call(result)

        expect(serialized[:runtime]).to eq(0.0)
      end

      it "handles measured runtime" do
        allow(result).to receive(:runtime).and_return(1.5)

        serialized = described_class.call(result)

        expect(serialized[:runtime]).to eq(1.5)
      end
    end

    context "when error handling" do
      it "raises error when TaskSerializer fails" do
        allow(CMDx::TaskSerializer).to receive(:call).and_raise(StandardError, "task error")

        expect { described_class.call(result) }.to raise_error(StandardError, "task error")
      end

      it "raises error when result doesn't respond to required methods" do
        invalid_result = Object.new
        allow(invalid_result).to receive(:task).and_return(task)

        expect { described_class.call(invalid_result) }.to raise_error(NoMethodError)
      end

      it "raises error when task is invalid for TaskSerializer" do
        allow(CMDx::TaskSerializer).to receive(:call).and_raise(TypeError, "invalid task")

        expect { described_class.call(result) }.to raise_error(TypeError, "invalid task")
      end
    end
  end

  describe "STRIP_FAILURE" do
    let(:mock_result) { double("result") }
    let(:hash) { { existing: "data" } }
    let(:failure_data) { { class: "FailedTask", caused_failure: "nested", threw_failure: "nested" } }
    let(:mock_failure) { double("failure", to_h: failure_data) }

    context "when result has the failure" do
      before do
        allow(mock_result).to receive_messages(caused_failure?: true, caused_failure: mock_failure)
      end

      it "does not modify hash when result has caused_failure" do
        original_hash = hash.dup

        described_class::STRIP_FAILURE.call(hash, mock_result, :caused_failure)

        expect(hash).to eq(original_hash)
      end
    end

    context "when result does not have the failure" do
      before do
        allow(mock_result).to receive_messages(caused_failure?: false, caused_failure: mock_failure)
      end

      it "adds stripped failure data to hash" do
        described_class::STRIP_FAILURE.call(hash, mock_result, :caused_failure)

        expect(hash[:caused_failure]).to eq(class: "FailedTask")
      end

      it "preserves existing hash data" do
        described_class::STRIP_FAILURE.call(hash, mock_result, :caused_failure)

        expect(hash[:existing]).to eq("data")
      end

      it "removes caused_failure and threw_failure from nested data" do
        described_class::STRIP_FAILURE.call(hash, mock_result, :caused_failure)

        expect(hash[:caused_failure]).not_to have_key(:caused_failure)
        expect(hash[:caused_failure]).not_to have_key(:threw_failure)
      end
    end

    context "with threw_failure" do
      before do
        allow(mock_result).to receive_messages(threw_failure?: false, threw_failure: mock_failure)
      end

      it "strips threw_failure when result doesn't have it" do
        described_class::STRIP_FAILURE.call(hash, mock_result, :threw_failure)

        expect(hash[:threw_failure]).to eq(class: "FailedTask")
        expect(hash[:threw_failure]).not_to have_key(:caused_failure)
        expect(hash[:threw_failure]).not_to have_key(:threw_failure)
      end
    end

    context "with different failure data structures" do
      it "handles empty failure data" do
        empty_failure = double("empty_failure", to_h: {})
        allow(mock_result).to receive_messages(caused_failure?: false, caused_failure: empty_failure)

        described_class::STRIP_FAILURE.call(hash, mock_result, :caused_failure)

        expect(hash[:caused_failure]).to eq({})
      end

      it "handles failure data without nested failures" do
        clean_failure = double("clean_failure", to_h: { class: "CleanTask", status: "failed" })
        allow(mock_result).to receive_messages(caused_failure?: false, caused_failure: clean_failure)

        described_class::STRIP_FAILURE.call(hash, mock_result, :caused_failure)

        expect(hash[:caused_failure]).to eq(class: "CleanTask", status: "failed")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LoggerSerializer do
  let(:task) { create_simple_task.new }
  let(:result) { CMDx::Result.new(task) }
  let(:mock_task_serializer) do
    {
      index: 0,
      chain_id: "chain_123",
      type: "Task",
      class: "SimpleTask",
      id: "task_456",
      tags: []
    }
  end

  before do
    allow(CMDx::TaskSerializer).to receive(:call).with(task).and_return(mock_task_serializer)
    allow(CMDx::ResultAnsi).to receive(:call)
  end

  describe ".call" do
    context "when message is a Result object" do
      let(:result_hash) do
        {
          state: "complete",
          status: "success",
          outcome: "good",
          index: 0,
          runtime: 0.001
        }
      end

      before do
        allow(result).to receive(:to_h).and_return(result_hash)
      end

      it "returns the result hash with origin set" do
        output = described_class.call("info", Time.now, task, result)

        expect(output).to eq(result_hash.merge(origin: "CMDx"))
      end

      it "preserves existing origin if already set in result" do
        result_hash[:origin] = "ExistingOrigin"

        output = described_class.call("info", Time.now, task, result)

        expect(output[:origin]).to eq("ExistingOrigin")
      end

      context "with ansi_colorize option" do
        let(:colored_state) { "\e[32mcomplete\e[0m" }
        let(:colored_status) { "\e[32msuccess\e[0m" }
        let(:colored_outcome) { "\e[32mgood\e[0m" }

        before do
          allow(CMDx::ResultAnsi).to receive(:call).with("complete").and_return(colored_state)
          allow(CMDx::ResultAnsi).to receive(:call).with("success").and_return(colored_status)
          allow(CMDx::ResultAnsi).to receive(:call).with("good").and_return(colored_outcome)
        end

        it "applies ANSI colorization to colored keys" do
          output = described_class.call("info", Time.now, task, result, ansi_colorize: true)

          expect(output[:state]).to eq(colored_state)
          expect(output[:status]).to eq(colored_status)
          expect(output[:outcome]).to eq(colored_outcome)
          expect(output[:index]).to eq(0) # Not colorized
          expect(output[:runtime]).to eq(0.001) # Not colorized
        end

        it "only colorizes keys that exist in result" do
          result_hash.delete(:outcome)

          output = described_class.call("info", Time.now, task, result, ansi_colorize: true)

          expect(output[:state]).to eq(colored_state)
          expect(output[:status]).to eq(colored_status)
          expect(output).not_to have_key(:outcome)
          expect(CMDx::ResultAnsi).not_to have_received(:call).with("good")
        end

        it "preserves result hash when keys are missing" do
          result_hash.delete(:state)
          result_hash.delete(:status)
          result_hash.delete(:outcome)

          output = described_class.call("info", Time.now, task, result, ansi_colorize: true)

          expect(output[:index]).to eq(0)
          expect(output[:runtime]).to eq(0.001)
          expect(CMDx::ResultAnsi).not_to have_received(:call)
        end
      end

      context "without ansi_colorize option" do
        it "does not apply ANSI colorization" do
          output = described_class.call("info", Time.now, task, result)

          expect(output[:state]).to eq("complete")
          expect(output[:status]).to eq("success")
          expect(output[:outcome]).to eq("good")
          expect(CMDx::ResultAnsi).not_to have_received(:call)
        end
      end
    end

    context "when message is not a Result object" do
      let(:message) { "Processing user data" }

      it "merges TaskSerializer output with message" do
        output = described_class.call("info", Time.now, task, message)

        expected = mock_task_serializer.merge(
          message: message,
          origin: "CMDx"
        )
        expect(output).to eq(expected)
      end

      it "delegates to TaskSerializer" do
        described_class.call("info", Time.now, task, message)

        expect(CMDx::TaskSerializer).to have_received(:call).with(task)
      end

      it "preserves origin if already set in TaskSerializer output" do
        mock_task_serializer[:origin] = "TaskOrigin"

        output = described_class.call("info", Time.now, task, message)

        expect(output[:origin]).to eq("TaskOrigin")
      end

      context "with different message types" do
        it "handles string messages" do
          output = described_class.call("info", Time.now, task, "test message")

          expect(output[:message]).to eq("test message")
        end

        it "handles hash messages" do
          hash_message = { action: "process", data: "test" }
          output = described_class.call("info", Time.now, task, hash_message)

          expect(output[:message]).to eq(hash_message)
        end

        it "handles nil messages" do
          output = described_class.call("info", Time.now, task, nil)

          expect(output[:message]).to be_nil
        end

        it "handles numeric messages" do
          output = described_class.call("info", Time.now, task, 42)

          expect(output[:message]).to eq(42)
        end
      end

      context "with ansi_colorize option" do
        it "ignores ansi_colorize option for non-Result messages" do
          output = described_class.call("info", Time.now, task, message, ansi_colorize: true)

          expected = mock_task_serializer.merge(
            message: message,
            origin: "CMDx"
          )
          expect(output).to eq(expected)
          expect(CMDx::ResultAnsi).not_to have_received(:call)
        end
      end
    end

    context "when parameter handling" do
      it "ignores severity parameter" do
        output = described_class.call("debug", Time.now, task, "message")

        expect(output).to include(message: "message")
      end

      it "ignores time parameter" do
        specific_time = Time.new(2024, 1, 1, 12, 0, 0)
        output = described_class.call("info", specific_time, task, "message")

        expect(output).to include(message: "message")
      end
    end

    context "with edge cases" do
      it "handles empty result hash" do
        allow(result).to receive(:to_h).and_return({})

        output = described_class.call("info", Time.now, task, result)

        expect(output).to eq({ origin: "CMDx" })
      end

      it "handles TaskSerializer returning empty hash" do
        allow(CMDx::TaskSerializer).to receive(:call).and_return({})

        output = described_class.call("info", Time.now, task, "message")

        expect(output).to eq({ message: "message", origin: "CMDx" })
      end
    end
  end

  describe "COLORED_KEYS constant" do
    it "contains expected keys for ANSI colorization" do
      expect(described_class::COLORED_KEYS).to eq(%i[state status outcome])
    end
  end
end

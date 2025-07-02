# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::LoggerSerializer do
  describe ".call" do
    let(:severity) { :info }
    let(:time) { Time.now }
    let(:task) { mock_task }
    let(:task_serializer_data) do
      {
        index: 0,
        chain_id: "test-chain-id",
        type: "Task",
        class: "TestTask",
        id: "test-task-id",
        tags: []
      }
    end

    before do
      allow(CMDx::TaskSerializer).to receive(:call).with(task).and_return(task_serializer_data)
    end

    context "when message is a plain string" do
      let(:message) { "Test log message" }

      it "includes task serializer data" do
        result = described_class.call(severity, time, task, message)

        expect(result).to include(task_serializer_data)
      end

      it "includes the message" do
        result = described_class.call(severity, time, task, message)

        expect(result[:message]).to eq("Test log message")
      end

      it "sets origin to CMDx" do
        result = described_class.call(severity, time, task, message)

        expect(result[:origin]).to eq("CMDx")
      end

      it "returns hash with all expected keys" do
        result = described_class.call(severity, time, task, message)

        expect(result).to include(
          origin: "CMDx",
          index: 0,
          chain_id: "test-chain-id",
          type: "Task",
          class: "TestTask",
          id: "test-task-id",
          tags: [],
          message: "Test log message"
        )
      end
    end

    context "when message is a plain object" do
      let(:message) { 42 }

      it "includes the message as-is" do
        result = described_class.call(severity, time, task, message)

        expect(result[:message]).to eq(42)
      end

      it "includes task serializer data" do
        result = described_class.call(severity, time, task, message)

        expect(result).to include(task_serializer_data)
      end

      it "sets origin to CMDx" do
        result = described_class.call(severity, time, task, message)

        expect(result[:origin]).to eq("CMDx")
      end
    end

    context "when message responds to to_h but is not a Result" do
      let(:message) { double("HashLikeMessage", to_h: { action: "process", item_id: 123 }) }

      before do
        allow(message).to receive(:is_a?).with(CMDx::Result).and_return(false)
      end

      it "merges message hash with task data" do
        result = described_class.call(severity, time, task, message)

        expect(result).to include(
          action: "process",
          item_id: 123,
          index: 0,
          chain_id: "test-chain-id",
          type: "Task",
          class: "TestTask",
          id: "test-task-id",
          tags: [],
          message: message
        )
      end

      it "sets origin to CMDx" do
        result = described_class.call(severity, time, task, message)

        expect(result[:origin]).to eq("CMDx")
      end
    end

    context "when message is a Result object" do
      let(:result_hash) do
        {
          state: "complete",
          status: "success",
          outcome: "success",
          metadata: {},
          runtime: 0.5,
          origin: "CMDx"
        }
      end
      let(:message) { double("Result", to_h: result_hash, is_a?: true) }

      before do
        allow(message).to receive(:is_a?).with(CMDx::Result).and_return(true)
      end

      it "returns the result hash directly" do
        result = described_class.call(severity, time, task, message)

        expect(result).to eq(result_hash)
      end

      it "preserves existing origin" do
        result = described_class.call(severity, time, task, message)

        expect(result[:origin]).to eq("CMDx")
      end

      it "does not include task serializer data" do
        result = described_class.call(severity, time, task, message)

        expect(result).not_to include(:index, :chain_id, :type, :class, :id, :tags)
      end

      it "does not include message field" do
        result = described_class.call(severity, time, task, message)

        expect(result).not_to have_key(:message)
      end

      context "when ansi_colorize option is false" do
        it "does not colorize result values" do
          result = described_class.call(severity, time, task, message, ansi_colorize: false)

          expect(result[:state]).to eq("complete")
          expect(result[:status]).to eq("success")
          expect(result[:outcome]).to eq("success")
        end
      end

      context "when ansi_colorize option is true" do
        let(:colorized_state) { "\e[32mcomplete\e[0m" }
        let(:colorized_status) { "\e[32msuccess\e[0m" }
        let(:colorized_outcome) { "\e[32msuccess\e[0m" }

        before do
          allow(CMDx::ResultAnsi).to receive(:call).with("complete").and_return(colorized_state)
          allow(CMDx::ResultAnsi).to receive(:call).with("success").and_return(colorized_status)
          allow(CMDx::ResultAnsi).to receive(:call).with("success").and_return(colorized_outcome)
        end

        it "colorizes state, status, and outcome values" do
          result = described_class.call(severity, time, task, message, ansi_colorize: true)

          expect(result[:state]).to eq(colorized_state)
          expect(result[:status]).to eq(colorized_status)
          expect(result[:outcome]).to eq(colorized_outcome)
        end

        it "calls ResultAnsi for each colored key" do
          described_class.call(severity, time, task, message, ansi_colorize: true)

          expect(CMDx::ResultAnsi).to have_received(:call).with("complete")
          expect(CMDx::ResultAnsi).to have_received(:call).with("success").twice
        end

        it "preserves non-colored values" do
          result = described_class.call(severity, time, task, message, ansi_colorize: true)

          expect(result[:metadata]).to eq({})
          expect(result[:runtime]).to eq(0.5)
        end
      end

      context "when result hash is missing colored keys" do
        let(:result_hash) { { state: "running", metadata: {} } }

        before do
          allow(CMDx::ResultAnsi).to receive(:call).with("running").and_return("\e[33mrunning\e[0m")
        end

        it "only colorizes existing keys" do
          result = described_class.call(severity, time, task, message, ansi_colorize: true)

          expect(result[:state]).to eq("\e[33mrunning\e[0m")
          expect(result).not_to have_key(:status)
          expect(result).not_to have_key(:outcome)
        end
      end
    end

    context "when message is nil" do
      let(:message) { nil }

      it "includes nil as message" do
        result = described_class.call(severity, time, task, message)

        expect(result[:message]).to be_nil
      end

      it "includes task serializer data" do
        result = described_class.call(severity, time, task, message)

        expect(result).to include(task_serializer_data)
      end
    end

    context "when options contain additional keys" do
      let(:message) { "test message" }
      let(:options) { { custom_key: "custom_value", another_key: 123 } }

      it "ignores non-ansi_colorize options" do
        result = described_class.call(severity, time, task, message, **options)

        expect(result).not_to have_key(:custom_key)
        expect(result).not_to have_key(:another_key)
      end
    end

    context "when origin is not present in message hash" do
      let(:message) { double("Message", to_h: { data: "test" }, is_a?: false) }

      it "sets origin to CMDx" do
        result = described_class.call(severity, time, task, message)

        expect(result[:origin]).to eq("CMDx")
      end
    end

    context "when origin is already present in message hash" do
      let(:existing_origin) { "CustomOrigin" }
      let(:message) { double("Message", to_h: { origin: existing_origin }, is_a?: true) }

      before do
        allow(message).to receive(:is_a?).with(CMDx::Result).and_return(true)
      end

      it "preserves existing origin" do
        result = described_class.call(severity, time, task, message)

        expect(result[:origin]).to eq(existing_origin)
      end
    end

    context "when TaskSerializer raises an error" do
      let(:message) { "test message" }

      before do
        allow(CMDx::TaskSerializer).to receive(:call).with(task).and_raise(StandardError, "serialization error")
      end

      it "allows the error to propagate" do
        expect { described_class.call(severity, time, task, message) }.to raise_error(StandardError, "serialization error")
      end
    end

    context "when ResultAnsi raises an error" do
      let(:result_hash) { { state: "complete", status: "success" } }
      let(:message) { double("Result", to_h: result_hash, is_a?: true) }

      before do
        allow(message).to receive(:is_a?).with(CMDx::Result).and_return(true)
        allow(CMDx::ResultAnsi).to receive(:call).and_raise(StandardError, "colorization error")
      end

      it "allows the error to propagate" do
        expect { described_class.call(severity, time, task, message, ansi_colorize: true) }.to raise_error(StandardError, "colorization error")
      end
    end

    context "when message to_h method raises an error" do
      let(:message) { double("Message") }

      before do
        allow(message).to receive(:respond_to?).with(:to_h).and_return(true)
        allow(message).to receive(:to_h).and_raise(StandardError, "to_h error")
      end

      it "allows the error to propagate" do
        expect { described_class.call(severity, time, task, message) }.to raise_error(StandardError, "to_h error")
      end
    end
  end
end

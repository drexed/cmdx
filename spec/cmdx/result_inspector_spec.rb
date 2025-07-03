# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultInspector do
  describe ".call" do
    context "when inspecting basic result information" do
      it "formats class name with colon" do
        result_hash = { class: "ProcessOrderTask" }

        output = described_class.call(result_hash)

        expect(output).to eq("ProcessOrderTask:")
      end

      it "formats basic attributes with key=value pairs" do
        result_hash = {
          class: "ProcessOrderTask",
          type: "Task",
          index: 0,
          state: "complete"
        }

        output = described_class.call(result_hash)

        expect(output).to eq("ProcessOrderTask: type=Task index=0 state=complete")
      end

      it "handles string and numeric values" do
        result_hash = {
          class: "MyTask",
          id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          index: 42,
          runtime: 1.5
        }

        output = described_class.call(result_hash)

        expect(output).to eq("MyTask: index=42 id=018c2b95-b764-7615-a924-cc5b910ed1e5 runtime=1.5")
      end

      it "includes all standard result attributes" do
        result_hash = {
          class: "ComplexTask",
          type: "Task",
          index: 1,
          id: "abc123",
          state: "complete",
          status: "success",
          outcome: "success"
        }

        output = described_class.call(result_hash)

        expect(output).to eq("ComplexTask: type=Task index=1 id=abc123 state=complete status=success outcome=success")
      end
    end

    context "when inspecting result metadata" do
      it "formats metadata hash" do
        result_hash = {
          class: "ProcessOrderTask",
          metadata: { order_id: 123, user_id: 456 }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("ProcessOrderTask: metadata={order_id: 123, user_id: 456}")
      end

      it "handles empty metadata" do
        result_hash = {
          class: "SimpleTask",
          metadata: {}
        }

        output = described_class.call(result_hash)

        expect(output).to eq("SimpleTask: metadata={}")
      end

      it "handles metadata with various value types" do
        result_hash = {
          class: "VariedTask",
          metadata: { string_val: "test", number_val: 42, bool_val: true }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("VariedTask: metadata={string_val: \"test\", number_val: 42, bool_val: true}")
      end
    end

    context "when inspecting failure references" do
      it "formats caused_failure with special syntax" do
        result_hash = {
          class: "FailedTask",
          caused_failure: { index: 0, class: "ValidationTask", id: "val123" }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("FailedTask: caused_failure=<[0] ValidationTask: val123>")
      end

      it "formats threw_failure with special syntax" do
        result_hash = {
          class: "FailedTask",
          threw_failure: { index: 2, class: "ProcessingTask", id: "proc456" }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("FailedTask: threw_failure=<[2] ProcessingTask: proc456>")
      end

      it "formats both caused_failure and threw_failure" do
        result_hash = {
          class: "FailedTask",
          caused_failure: { index: 1, class: "InputTask", id: "input789" },
          threw_failure: { index: 3, class: "OutputTask", id: "output012" }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("FailedTask: caused_failure=<[1] InputTask: input789> threw_failure=<[3] OutputTask: output012>")
      end

      it "includes failure references with other attributes" do
        result_hash = {
          class: "ComplexFailedTask",
          type: "Task",
          index: 5,
          state: "interrupted",
          status: "failed",
          caused_failure: { index: 2, class: "DependencyTask", id: "dep345" }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("ComplexFailedTask: type=Task index=5 state=interrupted status=failed caused_failure=<[2] DependencyTask: dep345>")
      end
    end

    context "when inspecting execution information" do
      it "includes runtime information" do
        result_hash = {
          class: "TimedTask",
          runtime: 2.5
        }

        output = described_class.call(result_hash)

        expect(output).to eq("TimedTask: runtime=2.5")
      end

      it "includes process ID information" do
        result_hash = {
          class: "ProcessTask",
          pid: 1234
        }

        output = described_class.call(result_hash)

        expect(output).to eq("ProcessTask: pid=1234")
      end

      it "includes tags information" do
        result_hash = {
          class: "TaggedTask",
          tags: %w[important user-action]
        }

        output = described_class.call(result_hash)

        expect(output).to eq("TaggedTask: tags=[\"important\", \"user-action\"]")
      end

      it "combines execution information with other attributes" do
        result_hash = {
          class: "FullTask",
          index: 0,
          runtime: 1.2,
          pid: 5678,
          tags: ["fast"]
        }

        output = described_class.call(result_hash)

        expect(output).to eq("FullTask: index=0 tags=[\"fast\"] pid=5678 runtime=1.2")
      end
    end

    context "when handling attribute ordering" do
      it "follows consistent key ordering" do
        result_hash = {
          runtime: 0.5,
          class: "OrderedTask",
          index: 1,
          type: "Task",
          id: "ordered123"
        }

        output = described_class.call(result_hash)

        expect(output).to eq("OrderedTask: type=Task index=1 id=ordered123 runtime=0.5")
      end

      it "places class first regardless of input order" do
        result_hash = {
          status: "success",
          metadata: { test: true },
          class: "StatusTask",
          state: "complete"
        }

        output = described_class.call(result_hash)

        expect(output).to eq("StatusTask: state=complete status=success metadata={test: true}")
      end

      it "maintains proper order with all attribute types" do
        result_hash = {
          threw_failure: { index: 1, class: "HelperTask", id: "help123" },
          runtime: 3.0,
          class: "ComprehensiveTask",
          metadata: { priority: "high" },
          type: "Task",
          index: 0,
          caused_failure: { index: 2, class: "DependTask", id: "dep456" }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("ComprehensiveTask: type=Task index=0 metadata={priority: \"high\"} runtime=3.0 caused_failure=<[2] DependTask: dep456> threw_failure=<[1] HelperTask: help123>")
      end
    end

    context "when handling missing or nil attributes" do
      it "skips missing keys" do
        result_hash = {
          class: "SparseTask",
          index: 1
        }

        output = described_class.call(result_hash)

        expect(output).to eq("SparseTask: index=1")
      end

      it "handles empty result hash" do
        result_hash = {}

        output = described_class.call(result_hash)

        expect(output).to eq("")
      end

      it "includes keys with nil values" do
        result_hash = {
          class: "NilTask",
          metadata: nil,
          runtime: 0.0
        }

        output = described_class.call(result_hash)

        expect(output).to eq("NilTask: metadata= runtime=0.0")
      end

      it "skips keys not in the ordered list" do
        result_hash = {
          class: "FilteredTask",
          index: 0,
          unknown_key: "ignored",
          another_unknown: 42
        }

        output = described_class.call(result_hash)

        expect(output).to eq("FilteredTask: index=0")
      end
    end

    context "when inspecting complex result scenarios" do
      it "handles comprehensive successful result" do
        result_hash = {
          class: "ProcessOrderTask",
          type: "Task",
          index: 0,
          id: "018c2b95-b764-7615-a924-cc5b910ed1e5",
          state: "complete",
          status: "success",
          outcome: "success",
          metadata: { order_id: 123, customer_id: 456 },
          runtime: 0.5,
          pid: 9876
        }

        output = described_class.call(result_hash)

        expect(output).to eq("ProcessOrderTask: type=Task index=0 id=018c2b95-b764-7615-a924-cc5b910ed1e5 state=complete status=success outcome=success metadata={order_id: 123, customer_id: 456} pid=9876 runtime=0.5")
      end

      it "handles comprehensive failed result" do
        result_hash = {
          class: "FailedProcessTask",
          type: "Task",
          index: 2,
          id: "failed-task-id",
          state: "interrupted",
          status: "failed",
          outcome: "failed",
          metadata: { error_code: 500, message: "Processing failed" },
          runtime: 1.8,
          caused_failure: { index: 0, class: "ValidationTask", id: "validation-id" },
          threw_failure: { index: 1, class: "NetworkTask", id: "network-id" }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("FailedProcessTask: type=Task index=2 id=failed-task-id state=interrupted status=failed outcome=failed metadata={error_code: 500, message: \"Processing failed\"} runtime=1.8 caused_failure=<[0] ValidationTask: validation-id> threw_failure=<[1] NetworkTask: network-id>")
      end

      it "handles skipped result with minimal information" do
        result_hash = {
          class: "SkippedTask",
          type: "Task",
          index: 1,
          state: "complete",
          status: "skipped",
          outcome: "skipped",
          metadata: { reason: "Already processed" }
        }

        output = described_class.call(result_hash)

        expect(output).to eq("SkippedTask: type=Task index=1 state=complete status=skipped outcome=skipped metadata={reason: \"Already processed\"}")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ResultInspector do
  describe ".call" do
    subject(:call) { described_class.call(result) }

    context "with empty result" do
      let(:result) { {} }

      it "returns empty string" do
        expect(call).to eq("")
      end
    end

    context "with basic result attributes" do
      let(:result) do
        {
          class: "TestTask",
          state: "complete",
          status: "success",
          id: "task_123"
        }
      end

      it "formats basic attributes with proper ordering" do
        expect(call).to eq("TestTask: id=task_123 state=complete status=success")
      end
    end

    context "with all ordered keys present" do
      let(:result) do
        {
          runtime: 1.5,
          class: "ProcessTask",
          pid: 12_345,
          tags: %w[urgent batch],
          metadata: { user: "admin" },
          outcome: "good",
          status: "success",
          state: "complete",
          index: 2,
          id: "proc_456",
          type: "workflow"
        }
      end

      it "formats all attributes in correct order" do
        expected = "ProcessTask: type=workflow index=2 id=proc_456 state=complete status=success outcome=good metadata={user: \"admin\"} tags=[\"urgent\", \"batch\"] pid=12345 runtime=1.5"
        expect(call).to eq(expected)
      end
    end

    context "with caused_failure information" do
      let(:result) do
        {
          class: "ValidationTask",
          state: "interrupted",
          status: "failed",
          caused_failure: {
            index: 1,
            class: "InputValidation",
            id: "val_789"
          }
        }
      end

      it "formats caused_failure with special syntax" do
        expect(call).to eq("ValidationTask: state=interrupted status=failed caused_failure=<[1] InputValidation: val_789>")
      end
    end

    context "with threw_failure information" do
      let(:result) do
        {
          class: "ProcessingTask",
          state: "interrupted",
          status: "failed",
          threw_failure: {
            index: 3,
            class: "DataProcessor",
            id: "proc_101"
          }
        }
      end

      it "formats threw_failure with special syntax" do
        expect(call).to eq("ProcessingTask: state=interrupted status=failed threw_failure=<[3] DataProcessor: proc_101>")
      end
    end

    context "with both failure types" do
      let(:result) do
        {
          class: "ChainTask",
          caused_failure: {
            index: 0,
            class: "InitialTask",
            id: "init_001"
          },
          threw_failure: {
            index: 2,
            class: "FinalTask",
            id: "final_003"
          }
        }
      end

      it "formats both failure types correctly" do
        expect(call).to eq("ChainTask: caused_failure=<[0] InitialTask: init_001> threw_failure=<[2] FinalTask: final_003>")
      end
    end

    context "with minimal result" do
      let(:result) { { id: "simple_task" } }

      it "formats single attribute" do
        expect(call).to eq("id=simple_task")
      end
    end

    context "with unordered keys in result hash" do
      let(:result) do
        {
          runtime: 2.1,
          id: "unordered_123",
          class: "UnorderedTask",
          index: 5,
          state: "executing"
        }
      end

      it "outputs keys in predefined order regardless of input order" do
        expect(call).to eq("UnorderedTask: index=5 id=unordered_123 state=executing runtime=2.1")
      end
    end

    context "with keys not in ORDERED_KEYS" do
      let(:result) do
        {
          class: "CustomTask",
          custom_field: "ignored",
          state: "complete",
          another_field: "also_ignored"
        }
      end

      it "only includes keys from ORDERED_KEYS" do
        expect(call).to eq("CustomTask: state=complete")
      end
    end

    context "with nil values" do
      let(:result) do
        {
          class: "NilTask",
          state: nil,
          status: "success"
        }
      end

      it "includes nil values in output" do
        expect(call).to eq("NilTask: state= status=success")
      end
    end

    context "with complex metadata values" do
      let(:result) do
        {
          class: "ComplexTask",
          metadata: { nested: { data: [1, 2, 3] } },
          tags: %w[tag1 tag2]
        }
      end

      it "includes complex values as string representations" do
        expect(call).to eq("ComplexTask: metadata={nested: {data: [1, 2, 3]}} tags=[\"tag1\", \"tag2\"]")
      end
    end

    context "when result doesn't respond to key? method" do
      let(:result) { "not a hash" }

      it "raises NoMethodError" do
        expect { call }.to raise_error(NoMethodError)
      end
    end

    context "when result has malformed failure data" do
      let(:result) do
        {
          class: "BrokenTask",
          caused_failure: { incomplete: "data" }
        }
      end

      it "handles missing failure keys gracefully" do
        expect(call).to eq("BrokenTask: caused_failure=<[] : >")
      end
    end

    context "with boolean values" do
      let(:result) do
        {
          class: "BooleanTask",
          status: true,
          outcome: false
        }
      end

      it "formats boolean values correctly" do
        expect(call).to eq("BooleanTask: status=true outcome=false")
      end
    end

    context "with numeric values" do
      let(:result) do
        {
          class: "NumericTask",
          index: 42,
          runtime: 3.14159,
          pid: 0
        }
      end

      it "formats numeric values correctly" do
        expect(call).to eq("NumericTask: index=42 pid=0 runtime=3.14159")
      end
    end
  end

  describe "ORDERED_KEYS constant" do
    it "contains expected keys in specific order" do
      expected_keys = %i[
        class type index id state status outcome metadata
        tags pid runtime caused_failure threw_failure
      ]
      expect(described_class::ORDERED_KEYS).to eq(expected_keys)
    end

    it "is frozen" do
      expect(described_class::ORDERED_KEYS).to be_frozen
    end
  end
end

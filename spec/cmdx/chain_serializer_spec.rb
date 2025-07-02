# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ChainSerializer do
  describe ".call" do
    let(:chain_id) { "018c2b95-b764-7615-a924-cc5b910ed1e5" }
    let(:chain) { double("Chain") }

    before do
      allow(chain).to receive_messages(
        id: chain_id,
        state: "complete",
        status: "success",
        outcome: "success",
        runtime: 0.5
      )
    end

    context "when chain has no results" do
      before do
        allow(chain).to receive(:results).and_return([])
      end

      it "returns hash with chain metadata" do
        result = described_class.call(chain)

        expect(result).to be_a(Hash)
        expect(result[:id]).to eq(chain_id)
        expect(result[:state]).to eq("complete")
        expect(result[:status]).to eq("success")
        expect(result[:outcome]).to eq("success")
        expect(result[:runtime]).to eq(0.5)
      end

      it "includes empty results array" do
        result = described_class.call(chain)

        expect(result[:results]).to eq([])
      end

      it "contains all expected keys" do
        result = described_class.call(chain)

        expect(result.keys).to contain_exactly(:id, :state, :status, :outcome, :runtime, :results)
      end
    end

    context "when chain has single result" do
      let(:task_result) { double("Result") }
      let(:result_hash) do
        {
          class: "SimpleTask",
          type: "Task",
          index: 0,
          id: "result-id",
          chain_id: chain_id,
          state: "complete",
          status: "success",
          outcome: "success",
          runtime: 0.1,
          metadata: {}
        }
      end

      before do
        allow(chain).to receive(:results).and_return([task_result])
        allow(task_result).to receive(:to_h).and_return(result_hash)
      end

      it "includes result in results array" do
        result = described_class.call(chain)

        expect(result[:results]).to eq([result_hash])
      end

      it "calls to_h on each result" do
        described_class.call(chain)

        expect(task_result).to have_received(:to_h)
      end

      it "preserves original result hash structure" do
        result = described_class.call(chain)
        serialized_result = result[:results].first

        expect(serialized_result[:class]).to eq("SimpleTask")
        expect(serialized_result[:type]).to eq("Task")
        expect(serialized_result[:index]).to eq(0)
        expect(serialized_result[:chain_id]).to eq(chain_id)
      end

      it "maintains chain-level metadata separately from result data" do
        result = described_class.call(chain)

        expect(result[:id]).to eq(chain_id)
        expect(result[:state]).to eq("complete")
        expect(result[:results].first[:state]).to eq("complete")
      end
    end

    context "when chain has multiple results" do
      let(:parent_result) { double("ParentResult") }
      let(:child_result_one) { double("ChildResult1") }
      let(:child_result_two) { double("ChildResult2") }
      let(:parent_result_hash) { { class: "ParentTask", index: 0, state: "complete" } }
      let(:child_result_one_hash) { { class: "ChildTask1", index: 1, state: "complete" } }
      let(:child_result_two_hash) { { class: "ChildTask2", index: 2, state: "complete" } }

      before do
        allow(chain).to receive(:results).and_return([parent_result, child_result_one, child_result_two])
        allow(parent_result).to receive(:to_h).and_return(parent_result_hash)
        allow(child_result_one).to receive(:to_h).and_return(child_result_one_hash)
        allow(child_result_two).to receive(:to_h).and_return(child_result_two_hash)
      end

      it "includes all results in results array" do
        result = described_class.call(chain)

        expect(result[:results]).to eq([parent_result_hash, child_result_one_hash, child_result_two_hash])
      end

      it "maintains result order" do
        result = described_class.call(chain)
        results = result[:results]

        expect(results[0][:class]).to eq("ParentTask")
        expect(results[1][:class]).to eq("ChildTask1")
        expect(results[2][:class]).to eq("ChildTask2")
      end

      it "calls to_h on each result" do
        described_class.call(chain)

        expect(parent_result).to have_received(:to_h)
        expect(child_result_one).to have_received(:to_h)
        expect(child_result_two).to have_received(:to_h)
      end

      it "handles different result structures" do
        result = described_class.call(chain)
        results = result[:results]

        results.each_with_index do |res, index|
          expect(res[:index]).to eq(index)
          expect(res[:state]).to eq("complete")
        end
      end
    end

    context "when chain has failed state" do
      let(:failed_result) { double("FailedResult") }
      let(:failed_result_hash) do
        {
          class: "FailingTask",
          state: "interrupted",
          status: "failed",
          outcome: "failed",
          metadata: { error: "Something went wrong" },
          runtime: 0.1
        }
      end

      before do
        allow(chain).to receive_messages(
          state: "interrupted",
          status: "failed",
          outcome: "failed",
          runtime: 0.1,
          results: [failed_result]
        )
        allow(failed_result).to receive(:to_h).and_return(failed_result_hash)
      end

      it "includes failure information in chain metadata" do
        result = described_class.call(chain)

        expect(result[:state]).to eq("interrupted")
        expect(result[:status]).to eq("failed")
        expect(result[:outcome]).to eq("failed")
      end

      it "includes failed result data" do
        result = described_class.call(chain)
        failed_result_data = result[:results].first

        expect(failed_result_data[:class]).to eq("FailingTask")
        expect(failed_result_data[:state]).to eq("interrupted")
        expect(failed_result_data[:metadata][:error]).to eq("Something went wrong")
      end
    end

    context "when handling nil values" do
      before do
        allow(chain).to receive_messages(
          state: nil,
          status: nil,
          outcome: nil,
          runtime: nil,
          results: []
        )
      end

      it "preserves nil values in serialization" do
        result = described_class.call(chain)

        expect(result[:state]).to be_nil
        expect(result[:status]).to be_nil
        expect(result[:outcome]).to be_nil
        expect(result[:runtime]).to be_nil
      end

      it "includes all keys even when values are nil" do
        result = described_class.call(chain)

        expect(result.keys).to contain_exactly(:id, :state, :status, :outcome, :runtime, :results)
      end
    end

    context "when handling different data types" do
      let(:complex_result) { double("ComplexResult") }
      let(:complex_result_hash) do
        {
          class: "ComplexTask",
          metadata: {
            error_code: 500,
            retry_count: 3,
            nested_data: { level1: { level2: "deep_value" } }
          },
          tags: %w[critical retry],
          timestamps: { started_at: Time.now, completed_at: Time.now + 10 },
          boolean_flag: true,
          numeric_value: 42.5
        }
      end

      before do
        allow(chain).to receive(:results).and_return([complex_result])
        allow(complex_result).to receive(:to_h).and_return(complex_result_hash)
      end

      it "preserves complex nested structures" do
        result = described_class.call(chain)
        serialized_result = result[:results].first

        expect(serialized_result[:metadata][:nested_data][:level1][:level2]).to eq("deep_value")
      end

      it "preserves array values" do
        result = described_class.call(chain)
        serialized_result = result[:results].first

        expect(serialized_result[:tags]).to eq(%w[critical retry])
      end

      it "preserves boolean and numeric values" do
        result = described_class.call(chain)
        serialized_result = result[:results].first

        expect(serialized_result[:boolean_flag]).to be(true)
        expect(serialized_result[:numeric_value]).to eq(42.5)
      end

      it "preserves hash values" do
        result = described_class.call(chain)
        serialized_result = result[:results].first

        expect(serialized_result[:timestamps]).to be_a(Hash)
        expect(serialized_result[:timestamps]).to have_key(:started_at)
        expect(serialized_result[:timestamps]).to have_key(:completed_at)
      end
    end

    context "when chain metadata has different types" do
      it "handles string runtime values" do
        allow(chain).to receive_messages(runtime: "0.5 seconds", results: [])

        result = described_class.call(chain)

        expect(result[:runtime]).to eq("0.5 seconds")
      end

      it "handles symbol status values" do
        allow(chain).to receive_messages(status: :success, results: [])

        result = described_class.call(chain)

        expect(result[:status]).to eq(:success)
      end

      it "handles numeric chain IDs" do
        allow(chain).to receive_messages(id: 12_345, results: [])

        result = described_class.call(chain)

        expect(result[:id]).to eq(12_345)
      end
    end

    context "when result to_h method raises errors" do
      let(:faulty_result) { double("FaultyResult") }

      before do
        allow(chain).to receive(:results).and_return([faulty_result])
        allow(faulty_result).to receive(:to_h).and_raise(StandardError.new("Serialization failed"))
      end

      it "allows errors to propagate" do
        expect { described_class.call(chain) }.to raise_error(StandardError, "Serialization failed")
      end
    end

    context "when result to_h returns unexpected values" do
      let(:odd_result) { double("OddResult") }

      before do
        allow(chain).to receive(:results).and_return([odd_result])
        allow(odd_result).to receive(:to_h).and_return("not a hash")
      end

      it "includes whatever to_h returns" do
        result = described_class.call(chain)

        expect(result[:results]).to eq(["not a hash"])
      end
    end

    context "when handling large result sets" do
      let(:results) { Array.new(100) { double("Result#{rand(1000)}") } }

      before do
        allow(chain).to receive(:results).and_return(results)
        results.each_with_index do |result, index|
          allow(result).to receive(:to_h).and_return({ index: index, class: "Task#{index}" })
        end
      end

      it "includes all results" do
        result = described_class.call(chain)

        expect(result[:results].size).to eq(100)
      end

      it "maintains result order for large sets" do
        result = described_class.call(chain)
        results_array = result[:results]

        results_array.each_with_index do |res, index|
          expect(res[:index]).to eq(index)
        end
      end
    end

    context "when results array is frozen" do
      let(:frozen_results) { [double("Result")].freeze }

      before do
        allow(chain).to receive(:results).and_return(frozen_results)
        allow(frozen_results.first).to receive(:to_h).and_return({ class: "FrozenTask" })
      end

      it "handles frozen results array" do
        result = described_class.call(chain)

        expect(result[:results]).to eq([{ class: "FrozenTask" }])
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ChainInspector do
  describe ".call" do
    let(:chain_id) { "018c2b95-b764-7615-a924-cc5b910ed1e5" }
    let(:chain) { mock_chain }

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

      it "generates header and footer with chain metadata" do
        output = described_class.call(chain)

        expect(output).to include("chain: #{chain_id}")
        expect(output).to include("state: complete | status: success | outcome: success | runtime: 0.5")
      end

      it "includes visual separators" do
        output = described_class.call(chain)

        expect(output).to match(/={40,}/)
      end

      it "formats output with proper spacing" do
        output = described_class.call(chain)

        expect(output).to start_with("\n")
        expect(output).to end_with("\n\n")
      end

      it "returns structured string format" do
        output = described_class.call(chain)
        lines = output.split("\n")

        expect(lines[1]).to eq("chain: #{chain_id}")
        expect(lines[2]).to match(/={40,}/)
        expect(lines[4]).to match(/={40,}/)
        expect(lines[5]).to include("state: complete")
      end
    end

    context "when chain has single result" do
      let(:result) { mock_result }
      let(:result_hash) do
        {
          class: "SimpleTask",
          type: "Task",
          index: 0,
          id: "result-id",
          state: "complete",
          status: "success",
          outcome: "success",
          runtime: 0.1
        }
      end

      before do
        allow(chain).to receive(:results).and_return([result])
        allow(result).to receive(:to_h).and_return(result_hash)
        allow(result_hash).to receive(:except).with(:chain_id).and_return(result_hash)
        allow(result_hash).to receive(:pretty_inspect).and_return("{\n  class: \"SimpleTask\",\n  index: 0\n}")
      end

      it "includes result data in output" do
        output = described_class.call(chain)

        expect(output).to include("class: \"SimpleTask\"")
        expect(output).to include("index: 0")
      end

      it "excludes chain_id from result data" do
        described_class.call(chain)

        expect(result_hash).to have_received(:except).with(:chain_id)
      end

      it "formats result using pretty_inspect" do
        described_class.call(chain)

        expect(result_hash).to have_received(:pretty_inspect)
      end

      it "structures output with header, result, and footer" do
        output = described_class.call(chain)
        lines = output.split("\n")

        header_line = lines.find { |line| line.include?("chain:") }
        footer_line = lines.find { |line| line.include?("state:") && line.include?("|") }

        expect(header_line).to include(chain_id)
        expect(footer_line).to include("state: complete | status: success")
      end
    end

    context "when chain has multiple results" do
      let(:parent_result) { mock_result }
      let(:child_result_one) { mock_result }
      let(:child_result_two) { mock_result }
      let(:parent_result_hash) { { class: "ParentTask", index: 0 } }
      let(:child_result_one_hash) { { class: "ChildTask1", index: 1 } }
      let(:child_result_two_hash) { { class: "ChildTask2", index: 2 } }

      before do
        allow(chain).to receive(:results).and_return([parent_result, child_result_one, child_result_two])

        [parent_result, child_result_one, child_result_two].each_with_index do |result, i|
          hash = [parent_result_hash, child_result_one_hash, child_result_two_hash][i]
          allow(result).to receive(:to_h).and_return(hash)
          allow(hash).to receive(:except).with(:chain_id).and_return(hash)
          allow(hash).to receive(:pretty_inspect).and_return("{ class: \"Task#{i + 1}\" }")
        end
      end

      it "includes all results in output" do
        output = described_class.call(chain)

        expect(output).to include("Task1")
        expect(output).to include("Task2")
        expect(output).to include("Task3")
      end

      it "maintains result order" do
        output = described_class.call(chain)

        task1_position = output.index("Task1")
        task2_position = output.index("Task2")
        task3_position = output.index("Task3")

        expect(task1_position).to be < task2_position
        expect(task2_position).to be < task3_position
      end

      it "processes each result individually" do
        described_class.call(chain)

        expect([parent_result_hash, child_result_one_hash, child_result_two_hash]).to all(have_received(:except).with(:chain_id))
        expect([parent_result_hash, child_result_one_hash, child_result_two_hash]).to all(have_received(:pretty_inspect))
      end
    end

    context "when chain has failed state" do
      before do
        allow(chain).to receive_messages(
          state: "interrupted",
          status: "failed",
          outcome: "failed",
          runtime: 0.1,
          results: []
        )
      end

      it "includes failure information in footer" do
        output = described_class.call(chain)

        expect(output).to include("state: interrupted")
        expect(output).to include("status: failed")
        expect(output).to include("outcome: failed")
      end

      it "maintains proper formatting for failed chains" do
        output = described_class.call(chain)

        expect(output).to include("chain: #{chain_id}")
        expect(output).to match(/={40,}/)
        expect(output).to start_with("\n")
        expect(output).to end_with("\n\n")
      end
    end

    context "when handling different chain metadata" do
      it "handles nil runtime values" do
        allow(chain).to receive_messages(runtime: nil, results: [])

        expect { described_class.call(chain) }.not_to raise_error

        output = described_class.call(chain)
        expect(output).to include("runtime: ")
      end

      it "handles string state values" do
        allow(chain).to receive_messages(state: "processing", results: [])

        output = described_class.call(chain)

        expect(output).to include("state: processing")
      end

      it "handles long chain IDs" do
        long_id = "very-long-chain-id-that-might-affect-formatting-018c2b95-b764-7615-a924-cc5b910ed1e5"
        allow(chain).to receive_messages(id: long_id, results: [])

        output = described_class.call(chain)

        expect(output).to include("chain: #{long_id}")
        expect(output).to match(/={40,}/)
      end
    end

    context "when dealing with separator line length" do
      it "adjusts separator length based on header size" do
        long_id = "a" * 100
        allow(chain).to receive_messages(id: long_id, results: [])

        output = described_class.call(chain)
        lines = output.split("\n")
        separator_line = lines.find { |line| line.match?(/^=+$/) }
        header_line = lines.find { |line| line.include?("chain:") }

        expect(separator_line.length).to be >= header_line.length
      end

      it "adjusts separator length based on footer size" do
        allow(chain).to receive_messages(
          status: "very-long-status-that-might-affect-separator-length",
          outcome: "very-long-outcome-description",
          results: []
        )

        output = described_class.call(chain)
        lines = output.split("\n")
        separator_line = lines.find { |line| line.match?(/^=+$/) }
        footer_line = lines.find { |line| line.include?("state:") && line.include?("|") }

        expect(separator_line.length).to be >= footer_line.length
      end
    end

    context "when handling complex result structures" do
      let(:result) { mock_result }
      let(:complex_hash) do
        {
          class: "ComplexTask",
          metadata: { error: "Something failed", attempts: 3 },
          tags: %w[critical retry],
          nested_data: { level1: { level2: "deep_value" } }
        }
      end

      before do
        allow(chain).to receive(:results).and_return([result])
        allow(result).to receive(:to_h).and_return(complex_hash)
        allow(complex_hash).to receive(:except).with(:chain_id).and_return(complex_hash)
        allow(complex_hash).to receive(:pretty_inspect).and_return("{\n  class: \"ComplexTask\",\n  metadata: {...}\n}")
      end

      it "handles complex nested structures" do
        output = described_class.call(chain)

        expect(output).to include("ComplexTask")
        expect(output).to include("metadata:")
      end

      it "delegates formatting to pretty_inspect" do
        described_class.call(chain)

        expect(complex_hash).to have_received(:pretty_inspect)
      end
    end

    context "when result to_h raises errors" do
      let(:result) { mock_result }

      before do
        allow(chain).to receive(:results).and_return([result])
        allow(result).to receive(:to_h).and_raise(StandardError.new("Serialization failed"))
      end

      it "allows errors to propagate" do
        expect { described_class.call(chain) }.to raise_error(StandardError, "Serialization failed")
      end
    end
  end
end

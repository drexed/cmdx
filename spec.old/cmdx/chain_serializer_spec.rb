# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ChainSerializer do
  describe ".call" do
    let(:mock_chain) do
      double(
        "chain",
        id: "chain_abc123",
        state: :complete,
        status: :success,
        outcome: :good,
        runtime: 1.25,
        results: [result_one, result_two]
      )
    end
    let(:result_one) { double("result_one", to_h: { id: "result_one", status: "success" }) }
    let(:result_two) { double("result_two", to_h: { id: "result_two", status: "failed" }) }

    context "with complete successful chain" do
      it "returns hash with chain metadata and serialized results" do
        serialized = described_class.call(mock_chain)

        expect(serialized).to eq(
          id: "chain_abc123",
          state: :complete,
          status: :success,
          outcome: :good,
          runtime: 1.25,
          results: [
            { id: "result_one", status: "success" },
            { id: "result_two", status: "failed" }
          ]
        )
      end

      it "delegates result serialization to result.to_h" do
        described_class.call(mock_chain)

        expect(result_one).to have_received(:to_h)
        expect(result_two).to have_received(:to_h)
      end
    end

    context "with different chain states" do
      it "handles initialized chain" do
        allow(mock_chain).to receive_messages(
          state: :initialized,
          status: :pending,
          outcome: :pending
        )

        serialized = described_class.call(mock_chain)

        expect(serialized).to include(
          state: :initialized,
          status: :pending,
          outcome: :pending
        )
      end

      it "handles executing chain" do
        allow(mock_chain).to receive_messages(
          state: :executing,
          status: :pending,
          outcome: :pending
        )

        serialized = described_class.call(mock_chain)

        expect(serialized).to include(
          state: :executing,
          status: :pending,
          outcome: :pending
        )
      end

      it "handles interrupted chain" do
        allow(mock_chain).to receive_messages(
          state: :interrupted,
          status: :failed,
          outcome: :bad
        )

        serialized = described_class.call(mock_chain)

        expect(serialized).to include(
          state: :interrupted,
          status: :failed,
          outcome: :bad
        )
      end
    end

    context "with different runtime values" do
      it "handles nil runtime" do
        allow(mock_chain).to receive(:runtime).and_return(nil)

        serialized = described_class.call(mock_chain)

        expect(serialized[:runtime]).to be_nil
      end

      it "handles zero runtime" do
        allow(mock_chain).to receive(:runtime).and_return(0.0)

        serialized = described_class.call(mock_chain)

        expect(serialized[:runtime]).to eq(0.0)
      end

      it "handles measured runtime" do
        allow(mock_chain).to receive(:runtime).and_return(2.456)

        serialized = described_class.call(mock_chain)

        expect(serialized[:runtime]).to eq(2.456)
      end
    end

    context "with different result collections" do
      it "handles empty results" do
        allow(mock_chain).to receive(:results).and_return([])

        serialized = described_class.call(mock_chain)

        expect(serialized[:results]).to eq([])
      end

      it "handles single result" do
        single_result = double("single_result", to_h: { id: "single", status: "success" })
        allow(mock_chain).to receive(:results).and_return([single_result])

        serialized = described_class.call(mock_chain)

        expect(serialized[:results]).to eq([{ id: "single", status: "success" }])
      end

      it "handles multiple results with complex data" do
        complex_result_one = double(
          "complex_result_one", to_h: {
            id: "complex1",
            status: "success",
            metadata: { user_id: 123, action: "create" },
            runtime: 0.05
          }
        )
        complex_result_two = double(
          "complex_result_two", to_h: {
            id: "complex2",
            status: "failed",
            metadata: { error: "validation failed", field: "email" },
            runtime: 0.02
          }
        )
        allow(mock_chain).to receive(:results).and_return([complex_result_one, complex_result_two])

        serialized = described_class.call(mock_chain)

        expect(serialized[:results]).to eq(
          [
            {
              id: "complex1",
              status: "success",
              metadata: { user_id: 123, action: "create" },
              runtime: 0.05
            },
            {
              id: "complex2",
              status: "failed",
              metadata: { error: "validation failed", field: "email" },
              runtime: 0.02
            }
          ]
        )
      end
    end

    context "when error handling" do
      it "raises error when chain doesn't respond to id" do
        invalid_chain = Object.new

        expect { described_class.call(invalid_chain) }.to raise_error(NoMethodError, /undefined method.*id/)
      end

      it "raises error when chain doesn't respond to required methods" do
        invalid_chain = Object.new
        allow(invalid_chain).to receive(:id).and_return("test")

        expect { described_class.call(invalid_chain) }.to raise_error(NoMethodError, /undefined method.*state/)
      end

      it "raises error when result doesn't respond to to_h" do
        invalid_result = Object.new
        valid_chain = double(
          "valid_chain",
          id: "test", state: :complete, status: :success,
          outcome: :good, runtime: 0.1, results: [invalid_result]
        )

        expect { described_class.call(valid_chain) }.to raise_error(NoMethodError, /undefined method.*to_h/)
      end

      it "handles result.to_h returning non-hash values" do
        invalid_result = double("invalid_result", to_h: "not_a_hash")
        allow(mock_chain).to receive(:results).and_return([invalid_result])

        serialized = described_class.call(mock_chain)

        expect(serialized[:results]).to eq(["not_a_hash"])
      end
    end

    context "when testing module interface" do
      it "is defined as module_function" do
        expect(described_class).to respond_to(:call)
      end

      it "can be called as class method" do
        expect { described_class.call(mock_chain) }.not_to raise_error
      end

      it "returns a hash" do
        result = described_class.call(mock_chain)

        expect(result).to be_a(Hash)
      end

      it "includes all expected keys" do
        result = described_class.call(mock_chain)

        expect(result.keys).to contain_exactly(:id, :state, :status, :outcome, :runtime, :results)
      end
    end
  end
end

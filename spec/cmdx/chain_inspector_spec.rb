# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::ChainInspector do
  describe ".call" do
    subject(:call) { described_class.call(chain) }

    let(:chain) { double("chain") }

    context "with basic chain attributes" do
      let(:result) { double("result", to_h: { state: "complete", status: "success" }) }

      before do
        allow(chain).to receive_messages(id: "abc123", results: [result], state: "complete", status: "success", outcome: "good", runtime: 0.001)
        allow(result.to_h).to receive(:except).with(:chain_id).and_return({ state: "complete", status: "success" })
      end

      it "formats chain with header, results, and footer" do
        expect(call).to include("chain: abc123")
        expect(call).to include("state: complete | status: success | outcome: good | runtime: 0.001")
        expect(call).to include("===================")
        expect(call).to include('state: "complete"')
      end

      it "starts and ends with newlines" do
        expect(call).to start_with("\n")
        expect(call).to end_with("\n\n")
      end
    end

    context "with multiple results" do
      let(:result_one) { double("result_one", to_h: { state: "complete", status: "success" }) }
      let(:result_two) { double("result_two", to_h: { state: "complete", status: "skipped" }) }

      before do
        allow(chain).to receive_messages(id: "multi123", results: [result_one, result_two], state: "complete", status: "success", outcome: "good", runtime: 0.025)
        allow(result_one.to_h).to receive(:except).with(:chain_id).and_return({ state: "complete", status: "success" })
        allow(result_two.to_h).to receive(:except).with(:chain_id).and_return({ state: "complete", status: "skipped" })
      end

      it "includes both results in output" do
        expect(call).to include("chain: multi123")
        expect(call).to include('state: "complete", status: "success"')
        expect(call).to include('state: "complete", status: "skipped"')
      end
    end

    context "with empty results" do
      before do
        allow(chain).to receive_messages(id: "empty123", results: [], state: "initialized", status: "pending", outcome: "unknown", runtime: 0.0)
      end

      it "formats chain with empty results section" do
        expect(call).to include("chain: empty123")
        expect(call).to include("state: initialized | status: pending | outcome: unknown | runtime: 0.0")
        expect(call).to include("===================")
      end
    end

    context "with long chain ID affecting spacer length" do
      before do
        allow(chain).to receive_messages(id: "very-long-chain-identifier-that-exceeds-footer-length", results: [], state: "complete", status: "success", outcome: "good", runtime: 0.5)
      end

      it "uses longest length for spacer" do
        header_length = "\nchain: very-long-chain-identifier-that-exceeds-footer-length".size
        footer_length = "state: complete | status: success | outcome: good | runtime: 0.5".size
        expected_spacer_length = [header_length, footer_length].max

        spacer_match = call.match(/\n(=+)\n/)
        expect(spacer_match[1].length).to eq(expected_spacer_length)
      end
    end

    context "with long footer affecting spacer length" do
      before do
        allow(chain).to receive_messages(id: "short", results: [], state: "very-very-very-long-state-name", status: "extremely-long-status-description", outcome: "exceptionally-detailed-outcome", runtime: 123.456789)
      end

      it "uses footer length for spacer when longer than header" do
        header_length = "\nchain: short".size
        footer_length = "state: very-very-very-long-state-name | status: extremely-long-status-description | outcome: exceptionally-detailed-outcome | runtime: 123.456789".size
        expected_spacer_length = [header_length, footer_length].max

        spacer_match = call.match(/\n(=+)\n/)
        expect(spacer_match[1].length).to eq(expected_spacer_length)
      end
    end

    context "with nil values in chain attributes" do
      before do
        allow(chain).to receive_messages(id: "nil123", results: [], state: nil, status: nil, outcome: nil, runtime: nil)
      end

      it "includes nil values in footer" do
        expect(call).to include("state:  | status:  | outcome:  | runtime: ")
      end
    end

    context "with result that excludes chain_id" do
      let(:result_hash) { { state: "complete", status: "success", chain_id: "should-be-excluded", extra: "data" } }
      let(:result) { double("result", to_h: result_hash) }

      before do
        allow(chain).to receive_messages(id: "exclude123", results: [result], state: "complete", status: "success", outcome: "good", runtime: 0.1)
        allow(result_hash).to receive(:except).with(:chain_id).and_return({ state: "complete", status: "success", extra: "data" })
      end

      it "excludes chain_id from result hash" do
        expect(call).not_to include("should-be-excluded")
        expect(call).to include("extra")
      end
    end

    context "when chain doesn't respond to required methods" do
      let(:invalid_chain) { "not a chain" }

      it "raises NoMethodError for missing id method" do
        expect { described_class.call(invalid_chain) }.to raise_error(NoMethodError)
      end
    end

    context "when chain.results doesn't respond to map" do
      before do
        allow(chain).to receive_messages(id: "broken123", results: "not an array", state: "broken", status: "error", outcome: "bad", runtime: 0.0)
      end

      it "raises NoMethodError" do
        expect { call }.to raise_error(NoMethodError)
      end
    end

    context "when result doesn't respond to to_h" do
      let(:invalid_result) { "not a result" }

      before do
        allow(chain).to receive_messages(id: "invalid123", results: [invalid_result], state: "broken", status: "error", outcome: "bad", runtime: 0.0)
      end

      it "raises NoMethodError" do
        expect { call }.to raise_error(NoMethodError)
      end
    end

    context "when result.to_h doesn't respond to except" do
      let(:result) { double("result", to_h: "not a hash") }

      before do
        allow(chain).to receive_messages(id: "except123", results: [result], state: "broken", status: "error", outcome: "bad", runtime: 0.0)
      end

      it "raises NoMethodError" do
        expect { call }.to raise_error(NoMethodError)
      end
    end

    context "with complex result data" do
      let(:complex_hash) { { nested: { data: [1, 2, 3] }, tags: %w[urgent batch], metadata: { user: "admin" } } }
      let(:result) { double("result", to_h: complex_hash) }

      before do
        allow(chain).to receive_messages(id: "complex123", results: [result], state: "complete", status: "success", outcome: "good", runtime: 0.15)
        allow(complex_hash).to receive(:except).with(:chain_id).and_return(complex_hash)
      end

      it "includes complex data structures in pretty format" do
        expect(call).to include("nested")
        expect(call).to include("data")
        expect(call).to include("urgent")
        expect(call).to include("admin")
      end
    end
  end

  describe "FOOTER_KEYS constant" do
    it "contains expected keys in specific order" do
      expected_keys = %i[state status outcome runtime]
      expect(described_class::FOOTER_KEYS).to eq(expected_keys)
    end

    it "is frozen" do
      expect(described_class::FOOTER_KEYS).to be_frozen
    end
  end
end

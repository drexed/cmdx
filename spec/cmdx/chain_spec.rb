# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Chain do
  after do
    # Clean up thread-local state after each test
    described_class.clear
  end

  describe ".current" do
    it "returns nil when no chain is set" do
      expect(described_class.current).to be_nil
    end

    it "returns the current thread-local chain when set" do
      chain = described_class.new
      described_class.current = chain

      expect(described_class.current).to be(chain)
    end

    it "maintains thread isolation" do
      main_chain = described_class.new(id: "main-thread")
      described_class.current = main_chain

      thread_chain = nil
      thread = Thread.new do
        thread_chain = described_class.new(id: "worker-thread")
        described_class.current = thread_chain
        described_class.current
      end
      thread_result = thread.join.value

      expect(described_class.current).to be(main_chain)
      expect(thread_result).to be(thread_chain)
      expect(main_chain.id).to eq("main-thread")
      expect(thread_chain.id).to eq("worker-thread")
    end
  end

  describe ".current=" do
    it "sets the current thread-local chain" do
      chain = described_class.new

      described_class.current = chain

      expect(described_class.current).to be(chain)
    end

    it "allows setting to nil" do
      chain = described_class.new
      described_class.current = chain

      described_class.current = nil

      expect(described_class.current).to be_nil
    end

    it "returns the chain that was set" do
      chain = described_class.new

      result = described_class.current = chain

      expect(result).to be(chain)
    end
  end

  describe ".clear" do
    it "clears the current thread-local chain" do
      chain = described_class.new
      described_class.current = chain

      described_class.clear

      expect(described_class.current).to be_nil
    end

    it "returns nil" do
      result = described_class.clear

      expect(result).to be_nil
    end

    it "works when no chain is set" do
      expect { described_class.clear }.not_to raise_error
      expect(described_class.current).to be_nil
    end
  end

  describe ".build" do
    let(:result) { mock_result }

    before do
      allow(result).to receive(:is_a?).with(CMDx::Result).and_return(true)
    end

    context "when no current chain exists" do
      it "creates a new chain" do
        expect(described_class.current).to be_nil

        chain = described_class.build(result)

        expect(chain).to be_a(described_class)
        expect(described_class.current).to be(chain)
      end

      it "adds the result to the new chain" do
        chain = described_class.build(result)

        expect(chain.results).to include(result)
      end
    end

    context "when a current chain exists" do
      let(:existing_chain) { described_class.new }

      before do
        described_class.current = existing_chain
      end

      it "uses the existing chain when building" do
        chain = described_class.build(result)

        expect(chain).to be(existing_chain)
      end

      it "adds the result to the existing chain" do
        described_class.build(result)

        expect(existing_chain.results).to include(result)
      end

      it "returns the same existing chain instance" do
        chain = described_class.build(result)

        expect(chain).to be(existing_chain)
        expect(chain.object_id).to eq(existing_chain.object_id)
      end
    end

    context "when given invalid input" do
      it "raises TypeError for non-Result objects" do
        invalid_object = double("NotAResult")
        allow(invalid_object).to receive(:is_a?).with(CMDx::Result).and_return(false)

        expect { described_class.build(invalid_object) }.to raise_error(TypeError, "must be a Result")
      end

      it "raises TypeError for nil input" do
        expect { described_class.build(nil) }.to raise_error(TypeError, "must be a Result")
      end

      it "raises TypeError for string input" do
        expect { described_class.build("not a result") }.to raise_error(TypeError, "must be a Result")
      end
    end
  end

  describe "#initialize" do
    context "when given no arguments" do
      before do
        allow(CMDx::Correlator).to receive(:id).and_return("current-correlation-id")
      end

      it "creates a chain with correlator ID" do
        chain = described_class.new

        expect(chain.id).to eq("current-correlation-id")
      end

      it "initializes with empty results array" do
        chain = described_class.new

        expect(chain.results).to eq([])
      end
    end

    context "when correlator has no ID" do
      before do
        allow(CMDx::Correlator).to receive_messages(id: nil, generate: "generated-uuid")
      end

      it "generates a new UUID" do
        chain = described_class.new

        expect(chain.id).to eq("generated-uuid")
      end
    end

    context "when given a custom ID" do
      it "uses the provided ID" do
        chain = described_class.new(id: "custom-chain-id")

        expect(chain.id).to eq("custom-chain-id")
      end

      it "ignores correlator ID when custom ID is provided" do
        allow(CMDx::Correlator).to receive(:id).and_return("ignored-id")

        chain = described_class.new(id: "custom-chain-id")

        expect(chain.id).to eq("custom-chain-id")
      end

      it "initializes with empty results array" do
        chain = described_class.new(id: "custom-chain-id")

        expect(chain.results).to eq([])
      end
    end

    context "when given other attributes" do
      it "ignores unknown attributes" do
        expect { described_class.new(unknown: "value") }.not_to raise_error
      end
    end
  end

  describe "#to_h" do
    let(:chain) { described_class.new(id: "test-chain") }
    let(:serialized_data) { { id: "test-chain", results: [] } }

    before do
      allow(CMDx::ChainSerializer).to receive(:call).with(chain).and_return(serialized_data)
    end

    it "calls ChainSerializer with self" do
      chain.to_h

      expect(CMDx::ChainSerializer).to have_received(:call).with(chain)
    end

    it "returns the serialized data" do
      result = chain.to_h

      expect(result).to eq(serialized_data)
    end
  end

  describe "#to_a" do
    let(:chain) { described_class.new(id: "test-chain") }
    let(:serialized_data) { { id: "test-chain", results: [] } }

    before do
      allow(CMDx::ChainSerializer).to receive(:call).with(chain).and_return(serialized_data)
    end

    it "is an alias for to_h" do
      expect(chain.to_a).to eq(chain.to_h)
    end

    it "calls ChainSerializer with self" do
      chain.to_a

      expect(CMDx::ChainSerializer).to have_received(:call).with(chain)
    end
  end

  describe "#to_s" do
    let(:chain) { described_class.new(id: "test-chain") }
    let(:inspection_output) { "Chain inspection output" }

    before do
      allow(CMDx::ChainInspector).to receive(:call).with(chain).and_return(inspection_output)
    end

    it "calls ChainInspector with self" do
      chain.to_s

      expect(CMDx::ChainInspector).to have_received(:call).with(chain)
    end

    it "returns the inspection output" do
      result = chain.to_s

      expect(result).to eq(inspection_output)
    end
  end

  describe "attribute delegation" do
    let(:chain) { described_class.new }
    let(:first_result) { mock_result }
    let(:middle_result) { mock_result }
    let(:last_result) { mock_result }

    before do
      chain.results.push(first_result, middle_result, last_result)
    end

    describe "delegation to results" do
      it "delegates size to results" do
        expect(chain.size).to eq(3)
      end

      it "delegates first to results" do
        expect(chain.first).to be(first_result)
      end

      it "delegates last to results" do
        expect(chain.last).to be(last_result)
      end

      it "delegates index to results" do
        allow(chain.results).to receive(:index).with(middle_result).and_return(1)

        expect(chain.index(middle_result)).to eq(1)
      end
    end

    describe "delegation to first result" do
      before do
        allow(first_result).to receive_messages(state: "complete", status: "success", outcome: "processed", runtime: 0.5)
      end

      it "delegates state to first result" do
        expect(chain.state).to eq("complete")
      end

      it "delegates status to first result" do
        expect(chain.status).to eq("success")
      end

      it "delegates outcome to first result" do
        expect(chain.outcome).to eq("processed")
      end

      it "delegates runtime to first result" do
        expect(chain.runtime).to eq(0.5)
      end
    end

    describe "delegation behavior with empty results" do
      let(:empty_chain) { described_class.new }

      it "handles size delegation gracefully" do
        expect(empty_chain.size).to eq(0)
      end

      it "handles first delegation gracefully" do
        expect(empty_chain.first).to be_nil
      end

      it "handles last delegation gracefully" do
        expect(empty_chain.last).to be_nil
      end

      it "handles state delegation gracefully when no first result" do
        expect { empty_chain.state }.to raise_error(NoMethodError)
      end
    end
  end

  describe "thread safety" do
    it "maintains separate chains across threads" do
      results = {}
      threads = []

      5.times do |i|
        threads << Thread.new do
          chain = described_class.new(id: "thread-#{i}")
          described_class.current = chain
          sleep(0.01) # Small delay to encourage thread interleaving
          results[i] = described_class.current.id
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(5)
      5.times do |i|
        expect(results[i]).to eq("thread-#{i}")
      end
    end

    it "does not leak chains between threads" do
      main_chain = described_class.new(id: "main")
      described_class.current = main_chain

      thread_chain_id = nil
      thread = Thread.new do
        described_class.current = described_class.new(id: "thread")
        thread_chain_id = described_class.current.id
      end
      thread.join

      expect(described_class.current.id).to eq("main")
      expect(thread_chain_id).to eq("thread")
    end
  end

  describe "integration scenarios" do
    context "when building multiple results" do
      let(:first_task_result) { mock_result }
      let(:second_task_result) { mock_result }
      let(:third_task_result) { mock_result }

      before do
        [first_task_result, second_task_result, third_task_result].each do |result|
          allow(result).to receive(:is_a?).with(CMDx::Result).and_return(true)
        end
      end

      it "maintains the same chain across multiple builds" do
        chain1 = described_class.build(first_task_result)
        chain2 = described_class.build(second_task_result)
        chain3 = described_class.build(third_task_result)

        expect(chain1).to be(chain2)
        expect(chain2).to be(chain3)
        expect(chain1.results).to eq([first_task_result, second_task_result, third_task_result])
      end

      it "preserves result order" do
        described_class.build(first_task_result)
        described_class.build(second_task_result)
        chain = described_class.build(third_task_result)

        expect(chain.results[0]).to be(first_task_result)
        expect(chain.results[1]).to be(second_task_result)
        expect(chain.results[2]).to be(third_task_result)
      end
    end

    context "when clearing and rebuilding chains" do
      let(:result) { mock_result }

      before do
        allow(result).to receive(:is_a?).with(CMDx::Result).and_return(true)
      end

      it "creates a new chain after clearing" do
        old_chain = described_class.build(result)
        old_chain_id = old_chain.id

        described_class.clear
        new_chain = described_class.build(result)

        expect(new_chain).not_to be(old_chain)
        expect(new_chain.id).not_to eq(old_chain_id)
        expect(new_chain.results).to eq([result])
      end
    end

    context "when using custom correlation IDs" do
      let(:result) { mock_result }

      before do
        allow(result).to receive(:is_a?).with(CMDx::Result).and_return(true)
        allow(CMDx::Correlator).to receive(:id).and_return("correlation-123")
      end

      it "uses correlator ID for new chains" do
        chain = described_class.build(result)

        expect(chain.id).to eq("correlation-123")
      end

      it "maintains correlation ID across multiple results" do
        chain1 = described_class.build(result)
        chain2 = described_class.build(result)

        expect(chain1.id).to eq("correlation-123")
        expect(chain2.id).to eq("correlation-123")
        expect(chain1).to be(chain2)
      end
    end
  end
end

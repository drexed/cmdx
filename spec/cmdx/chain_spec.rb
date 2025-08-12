# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Chain do
  subject(:chain) { described_class.new }

  let(:mock_task) { instance_double(CMDx::Task) }
  let(:mock_result) do
    instance_double(CMDx::Result, to_h: { id: "result-1" }).tap do |mock|
      allow(mock).to receive(:is_a?) do |klass|
        klass == CMDx::Result
      end
    end
  end
  let(:mock_result2) do
    instance_double(CMDx::Result, to_h: { id: "result-2" }).tap do |mock|
      allow(mock).to receive(:is_a?) do |klass|
        klass == CMDx::Result
      end
    end
  end

  before do
    allow(CMDx::Identifier).to receive(:generate).and_return("chain-id-123")
  end

  describe "#initialize" do
    it "generates a unique id" do
      expect(CMDx::Identifier).to receive(:generate)

      chain
    end

    it "initializes with an empty results array" do
      expect(chain.results).to eq([])
    end

    it "sets the id from Identifier.generate" do
      expect(chain.id).to eq("chain-id-123")
    end
  end

  describe "attr_readers" do
    it "provides read access to id" do
      expect(chain.id).to eq("chain-id-123")
    end

    it "provides read access to results" do
      expect(chain.results).to eq([])
    end
  end

  describe ".current" do
    after { described_class.clear }

    context "when no chain is set" do
      it "returns nil" do
        expect(described_class.current).to be_nil
      end
    end

    context "when a chain is set in current thread" do
      it "returns the current chain" do
        described_class.current = chain
        expect(described_class.current).to eq(chain)
      end
    end
  end

  describe ".current=" do
    after { described_class.clear }

    it "sets the current chain in thread storage" do
      described_class.current = chain
      expect(Thread.current[:cmdx_chain]).to eq(chain)
    end

    it "allows setting to nil" do
      described_class.current = chain
      described_class.current = nil
      expect(described_class.current).to be_nil
    end
  end

  describe ".clear" do
    before { described_class.current = chain }

    it "sets current chain to nil" do
      described_class.clear
      expect(described_class.current).to be_nil
    end

    it "clears thread storage" do
      described_class.clear
      expect(Thread.current[:cmdx_chain]).to be_nil
    end
  end

  describe ".build" do
    after { described_class.clear }

    context "when result is not a CMDx::Result" do
      it "raises TypeError" do
        expect { described_class.build("not-a-result") }.to raise_error(
          TypeError, "must be a CMDx::Result"
        )
      end

      it "raises TypeError for nil" do
        expect { described_class.build(nil) }.to raise_error(
          TypeError, "must be a CMDx::Result"
        )
      end
    end

    context "when result is a valid CMDx::Result" do
      context "when no current chain exists" do
        it "creates a new chain and sets it as current" do
          result_chain = described_class.build(mock_result)

          expect(result_chain).to be_a(described_class)
          expect(described_class.current).to eq(result_chain)
          expect(result_chain.results).to contain_exactly(mock_result)
        end
      end

      context "when a current chain already exists" do
        before { described_class.current = chain }

        it "uses the existing chain and adds the result" do
          result_chain = described_class.build(mock_result)

          expect(result_chain).to eq(chain)
          expect(chain.results).to contain_exactly(mock_result)
        end
      end

      context "when building multiple results" do
        before { described_class.current = chain }

        it "adds results in order" do
          described_class.build(mock_result)
          described_class.build(mock_result2)

          expect(chain.results).to eq([mock_result, mock_result2])
        end
      end
    end
  end

  describe "#to_h" do
    let(:result_hash1) { { id: "result-1", status: "success" } }
    let(:result_hash2) { { id: "result-2", status: "failed" } }

    before do
      allow(mock_result).to receive(:to_h).and_return(result_hash1)
      allow(mock_result2).to receive(:to_h).and_return(result_hash2)
    end

    context "when results array is empty" do
      it "returns hash with id and empty results array" do
        expect(chain.to_h).to eq(
          {
            id: "chain-id-123",
            results: []
          }
        )
      end
    end

    context "when results array has results" do
      before do
        chain.results << mock_result
        chain.results << mock_result2

        allow(mock_result).to receive(:to_h).and_return(result_hash1)
        allow(mock_result2).to receive(:to_h).and_return(result_hash2)
      end

      it "returns hash with id and results converted to hashes" do
        expect(chain.to_h).to eq(
          {
            id: "chain-id-123",
            results: [result_hash1, result_hash2]
          }
        )
      end

      it "calls to_h on each result" do
        expect(mock_result).to receive(:to_h)
        expect(mock_result2).to receive(:to_h)

        chain.to_h
      end
    end
  end

  describe "#to_s" do
    let(:formatted_string) { "id=\"chain-id-123\" results=[]" }

    it "converts to hash and formats as string" do
      expect(CMDx::Utils::Format).to receive(:to_str).with(
        {
          id: "chain-id-123",
          results: []
        }
      )

      chain.to_s
    end
  end

  describe "thread safety" do
    after { described_class.clear }

    it "maintains separate chains per thread" do
      thread1_chain = nil
      thread2_chain = nil

      thread1 = Thread.new do
        described_class.current = described_class.new
        thread1_chain = described_class.current
      end

      thread2 = Thread.new do
        described_class.current = described_class.new
        thread2_chain = described_class.current
      end

      thread1.join
      thread2.join

      expect(thread1_chain).not_to eq(thread2_chain)
      expect(thread1_chain).to be_a(described_class)
      expect(thread2_chain).to be_a(described_class)
    end

    it "does not interfere with main thread chain" do
      main_chain = described_class.new
      described_class.current = main_chain

      thread_chain = nil
      thread = Thread.new do
        described_class.current = described_class.new
        thread_chain = described_class.current
      end
      thread.join

      expect(described_class.current).to eq(main_chain)
      expect(thread_chain).not_to eq(main_chain)
    end
  end
end

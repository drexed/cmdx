# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Chain do
  subject(:chain) { described_class.new }

  let(:task) { create_simple_task.new }
  let(:result) { CMDx::Result.new(task) }

  describe "constants" do
    it "defines THREAD_KEY" do
      expect(described_class::THREAD_KEY).to eq(:cmdx_correlation_chain)
    end
  end

  describe "delegation" do
    let(:chain_with_results) do
      described_class.new.tap do |c|
        c.results << result
        c.results << CMDx::Result.new(create_simple_task.new)
      end
    end

    describe "results delegation" do
      it "delegates index to results (returns Enumerator)" do
        expect(chain_with_results.index).to be_a(Enumerator)
      end

      it "delegates index with arguments to results" do
        expect(chain_with_results.index(result)).to eq(0)
        expect(chain_with_results.index(chain_with_results.results.last)).to eq(1)
      end

      it "delegates first to results" do
        expect(chain_with_results.first).to eq(result)
      end

      it "delegates last to results" do
        expect(chain_with_results.last).to eq(chain_with_results.results.last)
      end

      it "delegates size to results" do
        expect(chain_with_results.size).to eq(2)
      end
    end

    describe "first result delegation" do
      before do
        allow(result).to receive_messages(state: "complete", status: "success", outcome: "good", runtime: 0.123)
      end

      it "delegates state to first result" do
        expect(chain_with_results.state).to eq("complete")
      end

      it "delegates status to first result" do
        expect(chain_with_results.status).to eq("success")
      end

      it "delegates outcome to first result" do
        expect(chain_with_results.outcome).to eq("good")
      end

      it "delegates runtime to first result" do
        expect(chain_with_results.runtime).to eq(0.123)
      end
    end
  end

  describe ".new" do
    context "without attributes" do
      it "generates a new ID using Correlator" do
        allow(CMDx::Correlator).to receive_messages(id: nil, generate: "generated-uuid")

        chain = described_class.new

        expect(chain.id).to eq("generated-uuid")
        expect(CMDx::Correlator).to have_received(:generate)
      end

      it "uses current correlation ID when available" do
        allow(CMDx::Correlator).to receive(:id).and_return("current-correlation-id")

        chain = described_class.new

        expect(chain.id).to eq("current-correlation-id")
      end

      it "initializes empty results array" do
        expect(chain.results).to eq([])
        expect(chain.results).to be_an(Array)
      end
    end

    context "with custom ID" do
      it "uses provided ID" do
        chain = described_class.new(id: "custom-123")

        expect(chain.id).to eq("custom-123")
      end

      it "does not call Correlator when ID provided" do
        allow(CMDx::Correlator).to receive(:id)
        allow(CMDx::Correlator).to receive(:generate)

        described_class.new(id: "custom-123")

        expect(CMDx::Correlator).not_to have_received(:id)
        expect(CMDx::Correlator).not_to have_received(:generate)
      end
    end
  end

  describe ".current" do
    it "retrieves chain from thread-local storage" do
      test_chain = described_class.new
      Thread.current[:cmdx_correlation_chain] = test_chain

      expect(described_class.current).to eq(test_chain)
    end

    it "returns nil when no chain is set" do
      Thread.current[:cmdx_correlation_chain] = nil

      expect(described_class.current).to be_nil
    end
  end

  describe ".current=" do
    it "sets chain in thread-local storage" do
      test_chain = described_class.new

      described_class.current = test_chain

      expect(Thread.current[:cmdx_correlation_chain]).to eq(test_chain)
    end

    it "allows setting to nil" do
      described_class.current = nil

      expect(Thread.current[:cmdx_correlation_chain]).to be_nil
    end

    it "returns the assigned chain" do
      test_chain = described_class.new

      result = described_class.current = test_chain

      expect(result).to eq(test_chain)
    end
  end

  describe ".clear" do
    it "clears current chain from thread-local storage" do
      Thread.current[:cmdx_correlation_chain] = described_class.new

      result = described_class.clear

      expect(Thread.current[:cmdx_correlation_chain]).to be_nil
      expect(result).to be_nil
    end

    it "returns nil when no chain was set" do
      Thread.current[:cmdx_correlation_chain] = nil

      result = described_class.clear

      expect(result).to be_nil
    end
  end

  describe ".build" do
    it "creates new chain when none exists" do
      described_class.current = nil

      chain = described_class.build(result)

      expect(chain).to be_a(described_class)
      expect(chain.results).to include(result)
      expect(described_class.current).to eq(chain)
    end

    it "extends existing chain with new result" do
      existing_chain = described_class.new
      described_class.current = existing_chain
      new_result = CMDx::Result.new(create_simple_task.new)

      chain = described_class.build(new_result)

      expect(chain).to eq(existing_chain)
      expect(chain.results).to include(new_result)
    end

    it "raises TypeError for non-Result objects" do
      expect { described_class.build("invalid") }.to raise_error(
        TypeError,
        "must be a Result"
      )
    end

    it "raises TypeError for nil" do
      expect { described_class.build(nil) }.to raise_error(
        TypeError,
        "must be a Result"
      )
    end

    it "accepts any object that is_a Result" do
      result_subclass = Class.new(CMDx::Result)
      custom_result = result_subclass.new(task)

      expect { described_class.build(custom_result) }.not_to raise_error
    end
  end

  describe "#to_h" do
    it "delegates to ChainSerializer" do
      serialized_data = { id: chain.id, results: [] }
      allow(CMDx::ChainSerializer).to receive(:call).with(chain).and_return(serialized_data)

      result = chain.to_h

      expect(result).to eq(serialized_data)
      expect(CMDx::ChainSerializer).to have_received(:call).with(chain)
    end
  end

  describe "#to_a" do
    it "aliases to_h" do
      expect(chain.method(:to_a)).to eq(chain.method(:to_h))
    end
  end

  describe "#to_s" do
    it "delegates to ChainInspector" do
      formatted_string = "chain: #{chain.id}\n===================\n"
      allow(CMDx::ChainInspector).to receive(:call).with(chain).and_return(formatted_string)

      result = chain.to_s

      expect(result).to eq(formatted_string)
      expect(CMDx::ChainInspector).to have_received(:call).with(chain)
    end
  end

  describe "thread safety" do
    it "maintains separate chains per thread" do
      main_chain = described_class.new(id: "main-thread")
      described_class.current = main_chain

      other_thread_chain = nil
      thread = Thread.new do
        described_class.current = described_class.new(id: "other-thread")
        other_thread_chain = described_class.current
      end
      thread.join

      expect(described_class.current).to eq(main_chain)
      expect(other_thread_chain.id).to eq("other-thread")
    end
  end

  describe "edge cases" do
    context "with empty results" do
      it "handles delegation gracefully" do
        expect { chain.first }.not_to raise_error
        expect { chain.last }.not_to raise_error
        expect { chain.size }.not_to raise_error
        expect(chain.size).to eq(0)
      end

      it "handles first result delegation when no results" do
        expect { chain.state }.to raise_error(NoMethodError)
        expect { chain.status }.to raise_error(NoMethodError)
        expect { chain.outcome }.to raise_error(NoMethodError)
        expect { chain.runtime }.to raise_error(NoMethodError)
      end
    end

    context "with frozen chain" do
      it "allows accessing results but chain itself is frozen" do
        chain.freeze

        expect(chain.frozen?).to be true
        expect { chain.results << result }.not_to raise_error
        expect(chain.results).to include(result)
      end

      it "prevents modification of chain attributes" do
        chain.freeze

        expect { chain.instance_variable_set(:@id, "new-id") }.to raise_error(FrozenError)
      end
    end
  end
end

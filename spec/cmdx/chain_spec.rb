# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Chain do
  after { described_class.clear }

  describe ".current, .current=, .clear" do
    it "stores the chain on the current fiber or thread" do
      chain = described_class.new
      described_class.current = chain
      expect(described_class.current).to equal(chain)
      described_class.clear
      expect(described_class.current).to be_nil
    end
  end

  describe ".build" do
    def minimal_result(**attrs)
      defaults = {
        task_id: CMDx::Identifier.generate,
        task_class: String,
        task_type: "string",
        task_tags: [],
        state: "complete",
        status: "success",
        reason: nil,
        cause: nil,
        metadata: {},
        strict: true,
        retries: 0,
        rolled_back: false,
        context: CMDx::Context.new,
        chain: nil,
        errors: CMDx::Errors.new,
        index: 0
      }
      CMDx::Result.new(**defaults, **attrs)
    end

    it "creates a chain when none exists and pushes the result" do
      described_class.clear
      r = minimal_result
      c = described_class.build(r)
      expect(c.results).to eq([r])
      expect(described_class.current).to equal(c)
    end

    it "extends the existing chain" do
      described_class.clear
      r1 = minimal_result
      r2 = minimal_result
      c1 = described_class.build(r1)
      c2 = described_class.build(r2)
      expect(c2).to equal(c1)
      expect(c2.results).to eq([r1, r2])
    end
  end

  describe "instance behavior" do
    subject(:chain) { described_class.new(dry_run: true) }

    let(:result) do
      CMDx::Result.new(
        task_id: "tid",
        task_class: String,
        task_type: "string",
        task_tags: [],
        state: "complete",
        status: "success",
        reason: nil,
        cause: nil,
        metadata: {},
        strict: true,
        retries: 0,
        rolled_back: false,
        context: CMDx::Context.new,
        chain: nil,
        errors: CMDx::Errors.new,
        index: 0
      )
    end

    describe "#push, #next_index" do
      it "appends results and next_index tracks size" do
        expect(chain.next_index).to eq(0)
        chain.push(result)
        expect(chain.next_index).to eq(1)
        expect(chain.results.size).to eq(1)
      end
    end

    describe "#dry_run?" do
      it "reflects the constructor flag" do
        expect(chain.dry_run?).to be true
        expect(described_class.new(dry_run: false).dry_run?).to be false
      end
    end

    describe "#first, #last, #size" do
      it "delegates to results" do
        chain.push(result)
        expect(chain.first).to equal(result)
        expect(chain.last).to equal(result)
        expect(chain.size).to eq(1)
      end
    end

    describe "#freeze" do
      it "freezes the results array" do
        chain.push(result)
        chain.freeze
        expect(chain.results).to be_frozen
        expect { chain.results << result }.to raise_error(FrozenError)
      end
    end

    describe "#to_h, #to_s" do
      it "serializes id, dry_run, and result hashes" do
        chain = described_class.new(dry_run: false)
        chain.push(result)
        h = chain.to_h
        expect(h[:id]).to be_a(String)
        expect(h[:dry_run]).to be false
        expect(h[:results].size).to eq(1)
        expect(chain.to_s).to include("id:")
      end
    end
  end
end

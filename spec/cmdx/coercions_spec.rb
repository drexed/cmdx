# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Coercions do
  subject(:coercions) { described_class.new }

  let(:task) { create_task_class.new }

  describe "#initialize" do
    it "registers the built-in coercions" do
      expect(coercions.registry.keys).to include(
        :array, :big_decimal, :boolean, :complex, :date, :date_time,
        :float, :hash, :integer, :rational, :string, :symbol, :time
      )
    end
  end

  describe "#initialize_copy" do
    it "dups the registry on dup" do
      copy = coercions.dup
      copy.deregister(:integer)

      expect(coercions.registry).to have_key(:integer)
      expect(copy.registry).not_to have_key(:integer)
    end
  end

  describe "#register" do
    it "adds a callable" do
      callable = ->(v, **) { v.to_s }
      coercions.register(:stringy, callable)

      expect(coercions.lookup(:stringy)).to be(callable)
    end

    it "accepts a block" do
      coercions.register(:upper) { |v, **| v.to_s.upcase }

      expect(coercions.lookup(:upper).call("hi")).to eq("HI")
    end

    it "raises when given both a callable and a block" do
      expect do
        coercions.register(:bad, ->(v, **) { v }) { |v, **| v }
      end.to raise_error(ArgumentError, /either a callable or a block/)
    end

    it "raises when the handler does not respond to call" do
      expect do
        coercions.register(:bad, Object.new)
      end.to raise_error(ArgumentError, /must respond to #call/)
    end
  end

  describe "#deregister" do
    it "removes a key" do
      coercions.deregister(:integer)

      expect(coercions.registry).not_to have_key(:integer)
    end
  end

  describe "#lookup" do
    it "raises on unknown keys" do
      expect { coercions.lookup(:bogus) }.to raise_error(CMDx::UnknownEntryError, "unknown coercion: bogus")
    end
  end

  describe "#empty? / #size" do
    it "reflects the registry" do
      expect(coercions).not_to be_empty
      expect(coercions.size).to eq(13)
    end
  end

  describe "#extract" do
    it "returns EMPTY_ARRAY for empty options" do
      expect(coercions.extract({})).to eq([])
    end

    it "returns EMPTY_ARRAY when :coerce is nil" do
      expect(coercions.extract(coerce: nil)).to eq([])
    end

    it "wraps a single symbol" do
      expect(coercions.extract(coerce: :integer)).to eq([[:integer, {}]])
    end

    it "expands an array of symbols" do
      expect(coercions.extract(coerce: %i[integer string])).to eq([[:integer, {}], [:string, {}]])
    end

    it "expands a hash with true values to empty options" do
      expect(coercions.extract(coerce: { integer: true })).to eq([[:integer, {}]])
    end

    it "preserves hash option values" do
      expect(coercions.extract(coerce: { date: { format: "%Y" } })).to eq([[:date, { format: "%Y" }]])
    end

    it "handles a callable" do
      callable = ->(v) { v }
      expect(coercions.extract(coerce: callable)).to eq([[callable, {}]])
    end

    it "raises for an unsupported scalar" do
      expect do
        coercions.extract(coerce: 42)
      end.to raise_error(ArgumentError, /unsupported type format/)
    end

    it "raises for an unsupported entry inside an array" do
      expect do
        coercions.extract(coerce: [42])
      end.to raise_error(ArgumentError, /unsupported coerce entry/)
    end
  end

  describe "#coerce" do
    it "returns the value untouched when there are no rules" do
      expect(coercions.coerce(task, :x, "42", [])).to eq("42")
    end

    it "applies a known coercion symbol" do
      expect(coercions.coerce(task, :x, "42", [[:integer, {}]])).to eq(42)
    end

    it "falls back to inline handler via Coerce" do
      handler = ->(v) { v.to_i * 2 }
      expect(coercions.coerce(task, :x, "3", [[handler, {}]])).to eq(6)
    end

    it "records the failure on the task's errors and returns the Failure" do
      result = coercions.coerce(task, :x, "abc", [[:integer, {}]])

      expect(result).to be_a(described_class::Failure)
      expect(task.errors[:x]).to include(result.message)
    end

    it "aggregates failures as 'into_any' when multiple built-ins fail" do
      result = coercions.coerce(task, :x, Object.new, [[:integer, {}], [:float, {}]])

      expect(result).to be_a(described_class::Failure)
      expect(result.message).to match(/(integer|float)/)
    end
  end
end

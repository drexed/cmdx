# frozen_string_literal: true

RSpec.describe CMDx::Result do
  subject(:result) do
    described_class.new(
      task_id: "abc-123", task_class: String, outcome:, context:,
      errors:, trace_id: "trace-1", tags: %w[test]
    )
  end

  let(:outcome) do
    o = CMDx::Outcome.new
    o.executing!
    o.complete!
    o
  end
  let(:context) { CMDx::Context.new(user: "Juan") }
  let(:errors) { CMDx::Errors.new }

  it "is always frozen" do
    expect(result).to be_frozen
  end

  it "exposes state and status as strings" do
    expect(result.state).to eq("complete")
    expect(result.status).to eq("success")
    expect(result).to be_success
    expect(result).to be_good
    expect(result).not_to be_bad
  end

  describe "#on" do
    it "yields when filter matches status" do
      yielded = false
      result.on(:success) { yielded = true }
      expect(yielded).to be true
    end

    it "yields when filter matches state" do
      yielded = false
      result.on(:complete) { yielded = true }
      expect(yielded).to be true
    end

    it "does not yield on mismatch" do
      yielded = false
      result.on(:failed) { yielded = true }
      expect(yielded).to be false
    end

    it "returns self for chaining" do
      expect(result.on(:success) { nil }).to eq(result)
    end
  end

  describe "#deconstruct_keys" do
    it "supports pattern matching" do
      case result
      in { status: "success", task_class: tc }
        expect(tc).to eq("String")
      else
        raise "no match"
      end
    end
  end

  describe "#to_h" do
    it "returns a serializable hash" do
      h = result.to_h
      expect(h[:task_id]).to eq("abc-123")
      expect(h[:status]).to eq("success")
      expect(h[:trace_id]).to eq("trace-1")
    end
  end
end

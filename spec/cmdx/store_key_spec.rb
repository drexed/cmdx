# frozen_string_literal: true

RSpec.describe CMDx::StoreKey do
  let(:task) do
    create_task_class do
      required :payment_id, coerce: :string
    end.new(payment_id: "pay_123")
  end

  before { task.class.inputs.resolve(task) }

  describe ".segment" do
    it "reads a Symbol via the task context" do
      expect(described_class.segment(task, :payment_id)).to eq("pay_123")
    end

    it "calls a Proc with the task" do
      expect(described_class.segment(task, ->(t) { t.context.payment_id })).to eq("pay_123")
    end

    it "returns static values" do
      expect(described_class.segment(task, "static")).to eq("static")
    end

    it "returns nil for blank segments" do
      expect(described_class.segment(task, :missing)).to be_nil
      expect(described_class.segment(task, "")).to be_nil
    end

    it "honors skip without touching context" do
      expect(task.context).not_to receive(:[])

      expect(described_class.segment(task, :class, skip: :class)).to be_nil
    end
  end

  describe ".compose" do
    it "joins coerced segments" do
      expect(described_class.compose("cmdx:idem", "ChargeCustomer", "pay_123")).to eq("cmdx:idem:ChargeCustomer:pay_123")
    end

    it "raises when a segment is empty" do
      expect { described_class.compose("cmdx:idem", "") }.to raise_error(ArgumentError, /store key must be non-empty/)
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Idempotency do
  let(:task_class) do
    create_task_class(name: "IdempotentTask") do
      required :payment_id, coerce: :string

      define_method(:work) do
        context.runs = (context.runs || 0) + 1
      end
    end
  end

  describe ".disabled" do
    it "returns a configuration with no key" do
      expect(described_class.disabled).not_to be_enabled
    end
  end

  describe "#build" do
    it "merges options and replaces the key" do
      base = described_class.new(:a, ttl: 100)
      built = base.build(:b, ttl: 200, namespace: "custom")

      expect(built.key).to eq(:b)
      expect(built.ttl).to eq(200)
      expect(built.namespace).to eq("custom")
    end

    it "returns self when nothing changes" do
      config = described_class.new(:payment_id)
      expect(config.build(nil, {})).to be(config)
    end
  end

  describe "#process" do
    it "runs work when disabled" do
      task = task_class.new(payment_id: "pay_1")
      config = described_class.disabled

      config.process(task) { task.work }

      expect(task.context.runs).to eq(1)
    end

    it "resolves segments from a task lambda" do
      klass = create_task_class(name: "LambdaIdemTask") do
        idempotent_by ->(t) { t.context.payment_id }
        required :payment_id, coerce: :string

        define_method(:work) { context.runs = 1 }
      end

      klass.execute(payment_id: "pay_lambda")
      expect(klass.execute(payment_id: "pay_lambda")).to be_skipped
    end

    it "skips duplicate invocations" do
      task_class.idempotent_by :payment_id
      first = task_class.execute(payment_id: "pay_1")
      second = task_class.execute(payment_id: "pay_1")

      expect(first).to be_ok
      expect(second).to be_skipped
      expect(second.metadata[:code]).to eq(:duplicate)
    end

    it "runs work when the resolved segment is blank" do
      task_class.idempotent_by :payment_id
      task = task_class.new(payment_id: "")
      config = task_class.idempotent_by

      config.process(task) { task.work }

      expect(task.context.runs).to eq(1)
      expect(CMDx::Stores.get("cmdx:idem:IdempotentTask:")).to be_nil
    end

    it "fails duplicates when on_duplicate is :fail" do
      klass = create_task_class(name: "FailDuplicateTask") do
        idempotent_by :payment_id, on_duplicate: :fail
        required :payment_id, coerce: :string

        define_method(:work) { nil }
      end

      klass.execute(payment_id: "pay_1")
      result = klass.execute(payment_id: "pay_1")

      expect(result).to be_ko
      expect(result.metadata[:code]).to eq(:duplicate)
    end
  end
end

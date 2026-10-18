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

    it "merges options while keeping the key when new_key is nil" do
      base = described_class.new(:payment_id, ttl: 100, on_duplicate: :skip)
      built = base.build(nil, ttl: 200, namespace: "custom")

      expect(built.key).to eq(:payment_id)
      expect(built.ttl).to eq(200)
      expect(built.namespace).to eq("custom")
      expect(built.on_duplicate).to eq(:skip)
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

    it "skips claiming when the if-guard is false" do
      task = task_class.new(payment_id: "pay_1")
      task.define_singleton_method(:active?) { false }
      config = described_class.new(:payment_id, if: :active?)

      config.process(task) { task.work }
      config.process(task) { task.work }

      expect(task.context.runs).to eq(2)
    end

    it "skips claiming when the unless-guard is true" do
      task = task_class.new(payment_id: "pay_1")
      task.define_singleton_method(:active?) { true }
      config = described_class.new(:payment_id, unless: :active?)

      2.times { config.process(task) { task.work } }

      expect(task.context.runs).to eq(2)
    end

    it "uses a static string segment in the store key" do
      klass = create_task_class(name: "StaticIdemTask") do
        idempotent_by "shared-segment", namespace: "app:idem"
        required :payment_id, coerce: :string

        define_method(:work) { nil }
      end

      klass.execute(payment_id: "pay_1")

      expect(CMDx::Stores.get("app:idem:#{klass.name}:shared-segment"))
        .to eq(described_class::COMPLETED)
    end

    it "releases the claim when work raises StandardError" do
      store_key = "cmdx:idem:IdempotentTask:pay_err"
      config = described_class.new(:payment_id)
      task = task_class.new(payment_id: "pay_err")

      expect { config.process(task) { raise StandardError, "boom" } }
        .to raise_error(StandardError, "boom")
      expect(CMDx::Stores.get(store_key)).to be_nil
    end

    it "skips in-flight duplicates with processing state metadata" do
      klass = create_task_class(name: "InflightIdemTask") do
        idempotent_by :payment_id
        required :payment_id, coerce: :string

        define_method(:work) { nil }
      end
      store_key = "cmdx:idem:#{klass.name}:pay_inflight"
      CMDx::Stores.set(store_key, described_class::PROCESSING, ttl: 300)

      result = klass.execute(payment_id: "pay_inflight")

      expect(result).to be_skipped
      expect(result.reason).to include("state=processing")
      expect(result.metadata[:idempotency_key]).to eq(store_key)
    end

    it "raises ArgumentError when on_duplicate is invalid" do
      config = described_class.new(:payment_id, on_duplicate: :reject)
      task = task_class.new(payment_id: "pay_bad")

      expect { config.send(:duplicate!, task, "cmdx:idem:Example:pay_bad") }
        .to raise_error(ArgumentError, /on_duplicate must be :skip or :fail/)
    end
  end

  describe "#mark_completed!" do
    it "raises IdempotencyError and releases the claim when the store refuses the transition" do
      store_key = "cmdx:idem:IdempotentTask:pay_completion"
      config = described_class.new(:payment_id, ttl: 300)
      CMDx::Stores.set(store_key, described_class::PROCESSING, ttl: 300)

      allow(CMDx::Stores).to receive(:set)
        .with(store_key, described_class::COMPLETED, xx: true, ttl: 300)
        .and_return(false)

      task = task_class.new(payment_id: "pay_completion")

      expect { config.send(:mark_completed!, store_key, task) }
        .to raise_error(CMDx::IdempotencyError, /failed to mark idempotency key completed/)
      expect(CMDx::Stores.get(store_key)).to be_nil
    end
  end

  describe "telemetry" do
    it "emits claimed and completed on a successful run" do
      events = []
      task_class.idempotent_by :payment_id
      task_class.telemetry.subscribe(:idempotency_claimed) { |e| events << e }
      task_class.telemetry.subscribe(:idempotency_completed) { |e| events << e }

      task_class.execute(payment_id: "pay_telemetry")

      expect(events.map(&:name)).to eq(%i[idempotency_claimed idempotency_completed])
      store_key = "cmdx:idem:#{task_class.name}:pay_telemetry"
      expect(events.first.payload[:idempotency_key]).to eq(store_key)
      expect(events.last.payload[:idempotency_key]).to eq(store_key)
    end

    it "emits idempotency_duplicate when the slot is already claimed" do
      events = []
      task_class.idempotent_by :payment_id
      task_class.telemetry.subscribe(:idempotency_duplicate) { |e| events << e }
      store_key = "cmdx:idem:#{task_class.name}:pay_dup"
      CMDx::Stores.set(store_key, described_class::COMPLETED, ttl: 300)

      task_class.execute(payment_id: "pay_dup")

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        code: :duplicate,
        idempotency_key: store_key,
        state: described_class::COMPLETED
      )
    end
  end
end

# frozen_string_literal: true

RSpec.describe CMDx::Lock do
  let(:task_class) do
    create_task_class(name: "LockedTask") do
      required :resource_id, coerce: :string

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
      config = described_class.new(:resource_id)
      expect(config.build(nil, {})).to be(config)
    end

    it "merges options when the key is unchanged" do
      base = described_class.new(:resource_id, ttl: 100)
      built = base.build(nil, wait: 5)

      expect(built.key).to eq(:resource_id)
      expect(built.ttl).to eq(100)
      expect(built.wait).to eq(5.0)
    end
  end

  describe "#process" do
    it "runs work when disabled" do
      task = task_class.new(resource_id: "r1")
      config = described_class.disabled

      config.process(task) { task.work }

      expect(task.context.runs).to eq(1)
    end

    it "serializes concurrent work for the same key" do
      task_class.lock_with :resource_id, wait: 2
      peak = 0
      current = 0
      mutex = Mutex.new

      klass = create_task_class(name: "ConcurrentLockTask") do
        lock_with :resource_id, wait: 2
        required :resource_id, coerce: :string

        define_method(:work) do
          mutex.synchronize do
            current += 1
            peak = current if current > peak
          end
          sleep 0.05
          mutex.synchronize { current -= 1 }
        end
      end

      threads = Array.new(3) do
        Thread.new { klass.execute(resource_id: "shared") }
      end
      threads.each(&:join)

      expect(peak).to eq(1)
      expect(threads.map(&:value)).to all(be_ok)
    end

    it "fails when the lock is held and wait is zero" do
      task_class.lock_with :resource_id, on_busy: :fail
      store_key = "cmdx:lock:#{task_class.name}:busy"
      CMDx::Stores.set(store_key, "other-holder", ttl: 300)

      result = task_class.execute(resource_id: "busy")

      expect(result).to be_ko
      expect(result.metadata[:code]).to eq(:busy)
      expect(result.metadata[:lock_key]).to eq(store_key)
    end

    it "skips when on_busy is :skip" do
      klass = create_task_class(name: "SkipBusyTask") do
        lock_with :resource_id, on_busy: :skip
        required :resource_id, coerce: :string

        define_method(:work) { context.runs = 1 }
      end
      store_key = "cmdx:lock:#{klass.name}:skip_me"
      CMDx::Stores.set(store_key, "other-holder", ttl: 300)

      result = klass.execute(resource_id: "skip_me")

      expect(result).to be_skipped
      expect(result.metadata[:code]).to eq(:busy)
    end

    it "runs work when the resolved segment is blank" do
      task_class.lock_with :resource_id
      task = task_class.new(resource_id: "")
      config = task_class.lock_with

      config.process(task) { task.work }

      expect(task.context.runs).to eq(1)
    end

    it "skips acquiring when the if-guard is false" do
      task = task_class.new(resource_id: "pay_1")
      task.define_singleton_method(:active?) { false }
      config = described_class.new(:resource_id, if: :active?)

      config.process(task) { task.work }
      config.process(task) { task.work }

      expect(task.context.runs).to eq(2)
    end

    it "skips acquiring when the unless-guard is true" do
      task = task_class.new(resource_id: "pay_1")
      task.define_singleton_method(:active?) { true }
      config = described_class.new(:resource_id, unless: :active?)

      2.times { config.process(task) { task.work } }

      expect(task.context.runs).to eq(2)
    end

    it "uses a static string segment and custom namespace in the store key" do
      klass = create_task_class(name: "StaticLockTask") do
        lock_with "shared-segment", namespace: "app:lock"
        required :resource_id, coerce: :string

        define_method(:work) do
          store_key = "app:lock:#{self.class.name}:shared-segment"
          context.seen = CMDx::Stores.get(store_key)
        end
      end

      result = klass.execute(resource_id: "ignored")

      expect(result.context.seen).to eq(result.tid)
      expect(CMDx::Stores.get("app:lock:#{klass.name}:shared-segment")).to be_nil
    end

    it "resolves a Proc segment for the store key" do
      klass = create_task_class(name: "ProcLockTask") do
        lock_with ->(t) { t.context.resource_id }
        required :resource_id, coerce: :string

        define_method(:work) { nil }
      end
      store_key = "cmdx:lock:#{klass.name}:proc_seg"
      task = klass.new(resource_id: "proc_seg")
      seen = nil

      klass.lock_with.process(task) { seen = CMDx::Stores.get(store_key) }

      expect(seen).to eq(task.tid)
    end

    it "raises ArgumentError when wait is negative" do
      config = described_class.new(:resource_id, wait: -1)
      task = task_class.new(resource_id: "neg")

      expect { config.process(task) { task.work } }
        .to raise_error(ArgumentError, /wait must be >= 0/)
    end

    it "acquires the lease after waiting for another holder to release" do
      order = []
      klass = create_task_class(name: "WaitAcquireTask") do
        lock_with :resource_id, wait: 2
        required :resource_id, coerce: :string
        optional :hold_for, coerce: :float, default: 0.0

        define_method(:work) do
          if context.hold_for.positive?
            order << :hold_start
            sleep context.hold_for
            order << :hold_end
          else
            order << :waiter
          end
        end
      end

      holder = Thread.new { klass.execute(resource_id: "w", hold_for: 0.2) }
      sleep 0.05
      waiter = Thread.new { klass.execute(resource_id: "w", hold_for: 0.0) }
      [holder, waiter].each(&:join)

      expect(order).to eq(%i[hold_start hold_end waiter])
      expect(holder.value).to be_ok
      expect(waiter.value).to be_ok
    end

    it "releases the lease when work raises StandardError" do
      config = described_class.new(:resource_id)
      task = task_class.new(resource_id: "r_err")
      store_key = "cmdx:lock:#{task_class.name}:r_err"

      expect { config.process(task) { raise StandardError, "boom" } }
        .to raise_error(StandardError, "boom")
      expect(CMDx::Stores.get(store_key)).to be_nil
    end

    it "raises ArgumentError when on_busy is invalid" do
      config = described_class.new(:resource_id, on_busy: :reject)
      task = task_class.new(resource_id: "bad")

      expect { config.send(:busy!, task, "cmdx:lock:Example:bad") }
        .to raise_error(ArgumentError, /on_busy must be :skip or :fail/)
    end

    it "includes holder and retry_after in busy metadata" do
      config = described_class.new(:resource_id, on_busy: :fail)
      task = task_class.new(resource_id: "meta")
      store_key = "cmdx:lock:#{task_class.name}:meta"
      CMDx::Stores.set(store_key, "stale-holder", ttl: 300)

      expect(task).to receive(:fail!).with(
        "lock held",
        code: :busy,
        lock_key: store_key,
        holder: "stale-holder",
        retry_after: be_between(1, 300)
      )

      config.send(:busy!, task, store_key)
    end

    it "signals skip with lock not acquired when the holder is unknown" do
      config = described_class.new(:resource_id, on_busy: :skip)
      task = task_class.new(resource_id: "ghost")
      store_key = "cmdx:lock:#{task_class.name}:ghost"

      allow(CMDx::Stores).to receive(:get).with(store_key).and_return(nil)
      allow(CMDx::Stores).to receive(:remaining_ttl).with(store_key).and_return(nil)

      expect(task).to receive(:skip!).with(
        "lock not acquired",
        code: :busy,
        lock_key: store_key
      )

      config.send(:busy!, task, store_key)
    end

    it "does not delete another holder's lease on release" do
      config = described_class.new(:resource_id)
      task = task_class.new(resource_id: "fence")
      store_key = "cmdx:lock:#{task_class.name}:fence"
      other_token = "other-holder-token"

      config.process(task) do
        CMDx::Stores.set(store_key, other_token, xx: true, ttl: 300)
        :done
      end

      expect(CMDx::Stores.get(store_key)).to eq(other_token)
    end

    it "stores the task tid in the lease value" do
      config = described_class.new(:resource_id)
      task = task_class.new(resource_id: "token")
      store_key = "cmdx:lock:#{task_class.name}:token"
      seen = nil

      config.process(task) do
        seen = CMDx::Stores.get(store_key)
        :done
      end

      expect(seen).to eq(task.tid)
      expect(CMDx::Stores.get(store_key)).to be_nil
    end
  end

  describe "telemetry" do
    it "emits lock_acquired when the lease is taken" do
      events = []
      task_class.lock_with :resource_id
      task_class.telemetry.subscribe(:lock_acquired) { |e| events << e }

      task_class.execute(resource_id: "r1")

      expect(events.map(&:name)).to eq([:lock_acquired])
      expect(events.first.payload[:lock_key]).to eq("cmdx:lock:#{task_class.name}:r1")
    end

    it "emits lock_busy when the lease cannot be acquired" do
      events = []
      task_class.lock_with :resource_id, on_busy: :skip
      task_class.telemetry.subscribe(:lock_busy) { |e| events << e }
      store_key = "cmdx:lock:#{task_class.name}:busy_telemetry"
      CMDx::Stores.set(store_key, "holder", ttl: 300)

      task_class.execute(resource_id: "busy_telemetry")

      expect(events.map(&:name)).to eq([:lock_busy])
      expect(events.first.payload).to include(code: :busy, lock_key: store_key, holder: "holder", on_busy: :skip)
    end

    it "does not emit when nothing is subscribed" do
      task_class.lock_with :resource_id

      expect { task_class.execute(resource_id: "r1") }.not_to raise_error
    end
  end
end

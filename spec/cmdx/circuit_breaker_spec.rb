# frozen_string_literal: true

RSpec.describe CMDx::CircuitBreaker do
  let(:task_class) do
    create_task_class(name: "BreakerTask") do
      required :sku, coerce: :string

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
      base = described_class.new(:class, threshold: 3)
      built = base.build(:sku, threshold: 5, cool_off: 10)

      expect(built.key).to eq(:sku)
      expect(built.threshold).to eq(5)
      expect(built.cool_off).to eq(10)
    end

    it "enables with :class when only options are passed on a disabled config" do
      built = described_class.disabled.build(nil, threshold: 2)

      expect(built).to be_enabled
      expect(built.key).to eq(:class)
      expect(built.threshold).to eq(2)
    end

    it "returns self when nothing changes" do
      config = described_class.new(:class)
      expect(config.build(nil, {})).to be(config)
    end

    it "merges options while keeping the key on an enabled config" do
      base = described_class.new(:sku, threshold: 3, window: 30)
      built = base.build(nil, threshold: 7, cool_off: 15)

      expect(built.key).to eq(:sku)
      expect(built.threshold).to eq(7)
      expect(built.cool_off).to eq(15)
      expect(built.window).to eq(30)
    end
  end

  describe "#process" do
    it "runs work when disabled" do
      task = task_class.new(sku: "A")
      config = described_class.disabled

      config.process(task) { task.work }

      expect(task.context.runs).to eq(1)
    end

    it "opens after threshold failures and fails fast" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "TripTask") do
        circuit_breaker :class, threshold: 2, cool_off: 60, window: 60
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      klass.execute(sku: "A")
      result = klass.execute(sku: "A")

      expect(result).to be_ko
      expect(result.metadata[:code]).to eq(:circuit_open)
    end

    it "clears the failure counter after success" do
      err = Class.new(StandardError)
      attempts = 0
      klass = create_task_class(name: "RecoverTask") do
        circuit_breaker :class, threshold: 2, cool_off: 60, window: 60
        required :sku, coerce: :string

        define_method(:work) do
          attempts += 1
          raise err if attempts == 1

          context.ok = true
        end
      end

      expect(klass.execute(sku: "A")).to be_ko
      expect(klass.execute(sku: "A")).to be_ok
      expect(klass.execute(sku: "A")).to be_ok
    end

    it "skips when on_open is :skip" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "SkipOpenTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on_open: :skip
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      result = klass.execute(sku: "A")

      expect(result).to be_skipped
      expect(result.metadata[:code]).to eq(:circuit_open)
    end

    it "includes the open store key and retry_after when the circuit is open" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "MetadataOpenTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on_open: :skip
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      result = klass.execute(sku: "A")

      expect(result.metadata[:circuit_breaker_key]).to eq("cmdx:cb:#{klass.name}:open")
      expect(result.metadata[:retry_after]).to be_between(1, 60)
    end

    it "does not trip when the keyed segment is blank" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "KeyedBlankTask") do
        circuit_breaker :tenant_id, threshold: 1, cool_off: 60
        optional :tenant_id

        define_method(:work) { raise err }
      end

      result = klass.execute

      expect(result).to be_ko
      expect(result.metadata[:code]).not_to eq(:circuit_open)
    end

    it "does not count exceptions outside on:" do
      api_err = Class.new(StandardError)
      klass = create_task_class(name: "FilteredTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on: [api_err]
        required :sku, coerce: :string

        define_method(:work) { raise NoMethodError }
      end

      3.times { klass.execute(sku: "A") }

      expect(klass.execute(sku: "A").metadata[:code]).not_to eq(:circuit_open)
    end

    it "isolates circuits per keyed segment" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "PerSkuTask") do
        circuit_breaker :sku, threshold: 2, cool_off: 60, window: 60
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      klass.execute(sku: "A")
      expect(klass.execute(sku: "B")).to be_ko
      expect(klass.execute(sku: "B").metadata[:code]).not_to eq(:circuit_open)
      expect(klass.execute(sku: "A")).to be_ko
      expect(klass.execute(sku: "A").metadata[:code]).to eq(:circuit_open)
    end

    it "skips checking when the if-guard is false" do
      err = Class.new(StandardError)
      attempts = 0
      klass = create_task_class(name: "IfGatedTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, if: :breaker_enabled?
        required :sku, coerce: :string

        define_method(:work) do
          attempts += 1
          raise err
        end

        define_method(:breaker_enabled?) { false }
      end

      3.times { klass.execute(sku: "A") }

      expect(attempts).to eq(3)
    end

    it "treats the circuit as closed when the open-key read fails" do
      err = Class.new(StandardError)
      open_key = "cmdx:cb:TreatClosedTask:open"
      CMDx::Stores.set(open_key, described_class::OPEN, ttl: 60)

      klass = create_task_class(name: "TreatClosedTask") do
        circuit_breaker :class, threshold: 5, cool_off: 60, on_open: :skip
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      allow(CMDx::Stores).to receive(:get).and_call_original
      allow(CMDx::Stores).to receive(:get).with(open_key).and_raise(StandardError, "store read failed")

      result = klass.execute(sku: "A")

      expect(result).to be_ko
      expect(result.metadata[:code]).not_to eq(:circuit_open)
    end

    it "does not trip when on: is an empty list" do
      err = Class.new(StandardError)
      klass = create_task_class(name: "NoOnTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on: []
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      3.times { klass.execute(sku: "A") }

      expect(klass.execute(sku: "A").metadata[:code]).not_to eq(:circuit_open)
    end

    it "raises ArgumentError when on_open is invalid" do
      config = described_class.new(:class, on_open: :halt)
      task = task_class.new(sku: "A")

      expect { config.send(:open!, task, "cmdx:cb:Example:open") }
        .to raise_error(ArgumentError, /on_open must be :fail or :skip/)
    end

    it "re-raises the work exception when the store fails during trip_open" do
      err = Class.new(StandardError) { def message = "dependency down" }
      failing_store = Class.new(CMDx::Stores::Memory) do
        def incr(*)
          raise StandardError, "store down"
        end
      end.new

      allow(CMDx.configuration).to receive(:store).and_return(failing_store)

      klass = create_task_class(name: "StoreTripFailTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60
        required :sku, coerce: :string

        define_method(:work) { raise err }
      end

      result = klass.execute(sku: "A")

      expect(result).to be_ko
      expect(result.reason).to include("dependency down")
      expect(result.metadata[:code]).not_to eq(:circuit_open)
    end
  end

  describe "telemetry" do
    it "emits circuit_tripped when the failure threshold is reached" do
      err = Class.new(StandardError)
      events = []
      klass = create_task_class(name: "TripTelemetryTask") do
        circuit_breaker :class, threshold: 2, cool_off: 60, window: 60
        required :sku, coerce: :string
        telemetry.subscribe(:circuit_tripped) { |e| events << e }

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      klass.execute(sku: "A")

      expect(events.size).to eq(1)
      expect(events.first.name).to eq(:circuit_tripped)
      expect(events.first.payload).to include(
        circuit_breaker_key: "cmdx:cb:#{klass.name}:open",
        failure_count: 2,
        threshold: 2,
        cool_off: 60
      )
    end

    it "emits circuit_open when work is blocked by an open circuit" do
      err = Class.new(StandardError)
      events = []
      klass = create_task_class(name: "OpenTelemetryTask") do
        circuit_breaker :class, threshold: 1, cool_off: 60, on_open: :skip
        required :sku, coerce: :string
        telemetry.subscribe(:circuit_open) { |e| events << e }

        define_method(:work) { raise err }
      end

      klass.execute(sku: "A")
      klass.execute(sku: "A")

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(
        code: :circuit_open,
        circuit_breaker_key: "cmdx:cb:#{klass.name}:open",
        on_open: :skip
      )
      expect(events.first.payload[:retry_after]).to be_between(1, 60)
    end

    it "emits circuit_failures_cleared after a successful run" do
      err = Class.new(StandardError)
      attempts = 0
      events = []
      klass = create_task_class(name: "ClearTelemetryTask") do
        circuit_breaker :class, threshold: 3, cool_off: 60, window: 60
        required :sku, coerce: :string
        telemetry.subscribe(:circuit_failures_cleared) { |e| events << e }

        define_method(:work) do
          attempts += 1
          raise err if attempts == 1

          context.ok = true
        end
      end

      klass.execute(sku: "A")
      klass.execute(sku: "A")

      expect(events.size).to eq(1)
      expect(events.first.payload[:failures_key]).to eq("cmdx:cb:#{klass.name}:failures")
    end
  end
end
